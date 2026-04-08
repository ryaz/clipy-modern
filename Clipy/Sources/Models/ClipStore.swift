import Foundation
import SwiftData
import AppKit
import CryptoKit

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }
    @Published var clips: [ClipItem] = []
    @Published var snippets: [SnippetFolder] = []

    private init() {
        let schema = Schema([ClipItem.self, SnippetFolder.self, SnippetItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { container = try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("SwiftData failed: \(error)") }
        loadClips()
    }

    func loadClips(limit: Int = 500) {
        var d = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        d.fetchLimit = limit
        clips = (try? context.fetch(d)) ?? []
    }

    @discardableResult
    func save(_ item: ClipItem) -> ClipItem {
        if let existing = clip(forHash: item.contentHash) {
            existing.updatedAt = Date()
            existing.sourceAppBundleID = item.sourceAppBundleID
            existing.sourceAppName = item.sourceAppName
            try? context.save(); loadClips(); return existing
        }
        context.insert(item); try? context.save(); pruneIfNeeded(); loadClips(); return item
    }

    func delete(_ item: ClipItem) { context.delete(item); try? context.save(); loadClips() }
    func clearAll() { try? context.delete(model: ClipItem.self); try? context.save(); loadClips() }
    func pin(_ item: ClipItem, pinned: Bool) { item.isPinned = pinned; try? context.save(); loadClips() }

    func updateAI(id: UUID, tags: [String], summary: String?) {
        guard let item = clip(forID: id) else { return }
        item.setAITags(tags); item.aiSummary = summary; item.aiIsProcessed = true
        try? context.save(); loadClips()
    }

    private func pruneIfNeeded() {
        let limit = max(UserDefaults.standard.integer(forKey: Constants.maxHistoryCount), 500)
        var d = FetchDescriptor<ClipItem>(predicate: #Predicate { !$0.isPinned }, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        d.fetchOffset = limit
        let overflow = (try? context.fetch(d)) ?? []
        overflow.forEach { context.delete($0) }
        if !overflow.isEmpty { try? context.save() }
    }

    private func clip(forHash hash: String) -> ClipItem? {
        let d = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })
        return try? context.fetch(d).first
    }

    func clip(forID id: UUID) -> ClipItem? {
        let d = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(d).first
    }

    func loadSnippets() {
        let d = FetchDescriptor<SnippetFolder>(sortBy: [SortDescriptor(\.index)])
        snippets = (try? context.fetch(d)) ?? []
    }

    func saveSnippet(folder: SnippetFolder) { context.insert(folder); try? context.save(); loadSnippets() }
    func deleteSnippet(folder: SnippetFolder) { context.delete(folder); try? context.save(); loadSnippets() }

    static func sha256(_ string: String) -> String { sha256(Data(string.utf8)) }
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
