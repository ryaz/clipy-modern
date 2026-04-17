import Foundation
import SwiftData
import AppKit
import CryptoKit
import os

private let logger = Logger(subsystem: "com.ryaz.clipy-modern", category: "ClipStore")

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()
    let container: ModelContainer
    private var _context: ModelContext
    @Published var clips: [ClipItem] = []
    @Published var snippets: [SnippetFolder] = []

    private init() {
        let schema = Schema([ClipItem.self, SnippetFolder.self, SnippetItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do { container = try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("SwiftData failed: \(error)") }
        _context = container.mainContext
        _context.autosaveEnabled = false
        loadClips()
    }

    func loadClips(limit: Int = 500) {
        var d = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        d.fetchLimit = limit
        do {
            clips = try _context.fetch(d)
        } catch {
            logger.error("loadClips failed: \(error.localizedDescription)")
            resetContext()
            clips = (try? _context.fetch(d)) ?? []
        }
    }

    @discardableResult
    func save(_ item: ClipItem) -> ClipItem {
        if let existing = clip(forHash: item.contentHash) {
            existing.updatedAt = Date()
            existing.sourceAppBundleID = item.sourceAppBundleID
            existing.sourceAppName = item.sourceAppName
            persistOrRecover(); loadClips(); return existing
        }
        _context.insert(item)
        persistOrRecover()
        pruneIfNeeded()
        loadClips()
        return item
    }

    func delete(_ item: ClipItem) { _context.delete(item); persistOrRecover(); loadClips() }

    func clearAll() {
        do { try _context.delete(model: ClipItem.self) } catch { logger.error("clearAll delete failed: \(error.localizedDescription)") }
        persistOrRecover(); loadClips()
    }

    func pin(_ item: ClipItem, pinned: Bool) { item.isPinned = pinned; persistOrRecover(); loadClips() }

    func updateAI(id: UUID, tags: [String], summary: String?) {
        guard let item = clip(forID: id) else { return }
        item.setAITags(tags); item.aiSummary = summary; item.aiIsProcessed = true
        persistOrRecover(); loadClips()
    }

    private func persistOrRecover() {
        do {
            try _context.save()
        } catch {
            logger.error("context.save failed: \(error.localizedDescription) — resetting context")
            resetContext()
        }
    }

    private func resetContext() {
        _context.rollback()
        _context = ModelContext(container)
        _context.autosaveEnabled = false
        logger.info("ModelContext reset")
    }

    private func pruneIfNeeded() {
        let limit = max(UserDefaults.standard.integer(forKey: Constants.maxHistoryCount), 500)
        var d = FetchDescriptor<ClipItem>(predicate: #Predicate { !$0.isPinned }, sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        d.fetchOffset = limit
        let overflow = (try? _context.fetch(d)) ?? []
        overflow.forEach { _context.delete($0) }
        if !overflow.isEmpty { persistOrRecover() }
    }

    private func clip(forHash hash: String) -> ClipItem? {
        let d = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.contentHash == hash })
        return try? _context.fetch(d).first
    }

    func clip(forID id: UUID) -> ClipItem? {
        let d = FetchDescriptor<ClipItem>(predicate: #Predicate { $0.id == id })
        return try? _context.fetch(d).first
    }

    func loadSnippets() {
        let d = FetchDescriptor<SnippetFolder>(sortBy: [SortDescriptor(\.index)])
        snippets = (try? _context.fetch(d)) ?? []
    }

    func saveSnippet(folder: SnippetFolder) { _context.insert(folder); persistOrRecover(); loadSnippets() }
    func deleteSnippet(folder: SnippetFolder) { _context.delete(folder); persistOrRecover(); loadSnippets() }

    nonisolated static func sha256(_ string: String) -> String { sha256(Data(string.utf8)) }
    nonisolated static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}
