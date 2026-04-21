import Foundation
import AppKit
import CryptoKit
import os

private let logger = Logger(subsystem: "com.ryaz.clipy-modern", category: "ClipStore")
private let keychainEncryptionKeyName = "clipy-modern-encryption-key"

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()
    @Published var clips: [ClipItem] = []
    @Published var snippets: [SnippetFolder] = []

    private let storageDir: URL
    private let clipsFile: URL
    private let snippetsFile: URL
    private let encryptionKey: SymmetricKey
    private var saveWorkItem: DispatchWorkItem?

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storageDir = appSupport.appendingPathComponent("com.ryaz.clipy-modern", isDirectory: true)
        clipsFile = storageDir.appendingPathComponent("clips.enc")
        snippetsFile = storageDir.appendingPathComponent("snippets.enc")
        try? FileManager.default.createDirectory(at: storageDir, withIntermediateDirectories: true)
        encryptionKey = Self.loadOrCreateKey()
        clips = Self.loadEncrypted(from: clipsFile, key: encryptionKey) ?? Self.migratePlaintext(dir: storageDir, key: encryptionKey)
        logger.info("Loaded \(self.clips.count) clips from disk")
    }

    @discardableResult
    func save(_ item: ClipItem) -> ClipItem {
        if let idx = clips.firstIndex(where: { $0.contentHash == item.contentHash }) {
            clips[idx].updatedAt = Date()
            clips[idx].sourceAppBundleID = item.sourceAppBundleID
            clips[idx].sourceAppName = item.sourceAppName
            sortClips()
            schedulePersist()
            return clips[idx]
        }
        clips.insert(item, at: 0)
        pruneIfNeeded()
        schedulePersist()
        return item
    }

    func delete(_ item: ClipItem) {
        clips.removeAll { $0.id == item.id }
        schedulePersist()
    }

    func clearAll() {
        clips.removeAll()
        schedulePersist()
    }

    func pin(_ item: ClipItem, pinned: Bool) {
        if let idx = clips.firstIndex(where: { $0.id == item.id }) {
            clips[idx].isPinned = pinned
            schedulePersist()
        }
    }

    func updateAI(id: UUID, tags: [String], summary: String?) {
        guard let idx = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[idx].setAITags(tags)
        clips[idx].aiSummary = summary
        clips[idx].aiIsProcessed = true
        schedulePersist()
    }

    func clip(forID id: UUID) -> ClipItem? {
        clips.first { $0.id == id }
    }

    // MARK: - Snippets

    func loadSnippets() {
        snippets = Self.loadEncrypted(from: snippetsFile, key: encryptionKey) ?? []
    }

    func saveSnippet(folder: SnippetFolder) {
        if let idx = snippets.firstIndex(where: { $0.id == folder.id }) {
            snippets[idx] = folder
        } else {
            snippets.append(folder)
        }
        Self.persistEncrypted(snippets, to: snippetsFile, key: encryptionKey)
    }

    func deleteSnippet(folder: SnippetFolder) {
        snippets.removeAll { $0.id == folder.id }
        Self.persistEncrypted(snippets, to: snippetsFile, key: encryptionKey)
    }

    // MARK: - Encrypted Persistence

    private func schedulePersist() {
        saveWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.persistClips() }
        }
        saveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    private func persistClips() {
        Self.persistEncrypted(clips, to: clipsFile, key: encryptionKey)
    }

    private static func persistEncrypted<T: Encodable>(_ value: T, to url: URL, key: SymmetricKey) {
        do {
            let json = try JSONEncoder().encode(value)
            let sealed = try AES.GCM.seal(json, using: key)
            guard let combined = sealed.combined else { throw CryptoKitError.underlyingCoreCryptoError(error: 0) }
            try combined.write(to: url, options: .atomic)
        } catch {
            logger.error("Failed to write \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    private static func loadEncrypted<T: Decodable>(from url: URL, key: SymmetricKey) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let json = try AES.GCM.open(box, using: key)
            return try JSONDecoder().decode(T.self, from: json)
        } catch {
            logger.error("Failed to decrypt/decode \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Encryption Key (Keychain-backed)

    private static func loadOrCreateKey() -> SymmetricKey {
        if let existing = KeychainHelper.readData(key: keychainEncryptionKeyName) {
            return SymmetricKey(data: existing)
        }
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        KeychainHelper.saveData(key: keychainEncryptionKeyName, value: keyData)
        logger.info("Generated new AES-256 encryption key")
        return key
    }

    // MARK: - Migration from plaintext

    private static func migratePlaintext(dir: URL, key: SymmetricKey) -> [ClipItem] {
        let plainFile = dir.appendingPathComponent("clips.json")
        guard let data = try? Data(contentsOf: plainFile) else { return [] }
        guard let clips = try? JSONDecoder().decode([ClipItem].self, from: data) else { return [] }
        logger.info("Migrating \(clips.count) clips from plaintext to encrypted")
        persistEncrypted(clips, to: dir.appendingPathComponent("clips.enc"), key: key)
        try? FileManager.default.removeItem(at: plainFile)
        return clips
    }

    // MARK: - Helpers

    private func sortClips() {
        clips.sort { $0.updatedAt > $1.updatedAt }
    }

    private func pruneIfNeeded() {
        let limit = max(UserDefaults.standard.integer(forKey: Constants.maxHistoryCount), 500)
        let pinned = clips.filter(\.isPinned)
        var unpinned = clips.filter { !$0.isPinned }
        if unpinned.count > limit {
            unpinned = Array(unpinned.prefix(limit))
        }
        clips = (pinned + unpinned).sorted { $0.updatedAt > $1.updatedAt }
    }

    nonisolated static func sha256(_ string: String) -> String { sha256(Data(string.utf8)) }
    nonisolated static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
