import Foundation
import AppKit

actor AIService {
    static let shared = AIService()
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let model = "claude-sonnet-4-20250514"
    private let queue = AsyncQueue()

    func process(_ item: ClipItem) async {
        guard item.clipType != .image, !item.stringValue.isEmpty, hasAPIKey else { return }
        await queue.enqueue { await self.runAnalysis(for: item) }
    }

    private func runAnalysis(for item: ClipItem) async {
        async let tags = fetchTags(for: item.stringValue)
        async let summary = item.stringValue.count > 300 ? fetchSummary(for: item.stringValue) : nil
        let t = await tags ?? []
        let s = await summary
        await MainActor.run { ClipStore.shared.updateAI(id: item.id, tags: t, summary: s) }
    }

    private func fetchTags(for text: String) async -> [String]? {
        let prompt = "Classify into tags (return ONLY a JSON array): code, sql, json, xml, html, markdown, url, email, phone, address, color, uuid, date, number, filepath\n\nText:\n\(text.prefix(800))"
        guard let r = await call(prompt: prompt, maxTokens: 64) else { return nil }
        return try? JSONDecoder().decode([String].self, from: Data(r.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
    }

    private func fetchSummary(for text: String) async -> String? {
        let prompt = "Summarize in ONE sentence (max 80 chars). Return only the summary.\n\nText:\n\(text.prefix(2000))"
        return await call(prompt: prompt, maxTokens: 100)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func smartSearch(query: String, in clips: [ClipItem]) async -> [UUID] {
        let snippets = clips.prefix(200).map { "[\($0.id.uuidString)]: \($0.displayTitle.prefix(120))" }.joined(separator: "\n")
        let prompt = "User searches clipboard for: \"\(query)\"\n\nReturn a JSON array of the top 10 most relevant UUIDs (full strings), ordered by relevance. ONLY the JSON array.\n\nClips:\n\(snippets)"
        guard let r = await call(prompt: prompt, maxTokens: 300),
              let ids = try? JSONDecoder().decode([String].self, from: Data(r.trimmingCharacters(in: .whitespacesAndNewlines).utf8))
        else { return [] }
        return ids.compactMap { UUID(uuidString: $0) }
    }

    private func call(prompt: String, maxTokens: Int) async -> String? {
        guard let key = apiKey else { return nil }
        let body: [String: Any] = ["model": model, "max_tokens": maxTokens, "messages": [["role": "user", "content": prompt]]]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"; req.httpBody = bodyData
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]]
        else { return nil }
        return content.first?["text"] as? String
    }

    var apiKey: String? { KeychainHelper.read(key: "anthropic-api-key") }
    nonisolated var hasAPIKey: Bool { KeychainHelper.read(key: "anthropic-api-key") != nil }
    func setAPIKey(_ key: String) { KeychainHelper.save(key: "anthropic-api-key", value: key) }
    func removeAPIKey() { KeychainHelper.delete(key: "anthropic-api-key") }
}

actor AsyncQueue {
    private var running = false
    private var pending: [() async -> Void] = []
    func enqueue(_ work: @escaping () async -> Void) async {
        pending.append(work)
        if !running { await drain() }
    }
    private func drain() async {
        running = true
        while !pending.isEmpty {
            let next = pending.removeFirst(); await next()
            try? await Task.sleep(for: .milliseconds(300))
        }
        running = false
    }
}

enum KeychainHelper {
    static func save(key: String, value: String) {
        saveData(key: key, value: Data(value.utf8))
    }
    static func read(key: String) -> String? {
        readData(key: key).flatMap { String(data: $0, encoding: .utf8) }
    }
    static func saveData(key: String, value: Data) {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecValueData as String: value]
        SecItemDelete(q as CFDictionary); SecItemAdd(q as CFDictionary, nil)
    }
    static func readData(key: String) -> Data? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key, kSecReturnData as String: true]
        var result: AnyObject?; SecItemCopyMatching(q as CFDictionary, &result)
        return result as? Data
    }
    static func delete(key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
    }
}
