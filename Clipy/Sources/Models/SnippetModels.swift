import Foundation

final class SnippetFolder: Codable, Identifiable {
    var id: UUID
    var title: String
    var index: Int
    var items: [SnippetItem]
    init(title: String, index: Int = 0) { self.id = UUID(); self.title = title; self.index = index; self.items = [] }
}

final class SnippetItem: Codable, Identifiable {
    var id: UUID
    var title: String
    var content: String
    var index: Int
    var shortcut: String?
    init(title: String, content: String, index: Int = 0, shortcut: String? = nil) {
        self.id = UUID(); self.title = title; self.content = content; self.index = index; self.shortcut = shortcut
    }
}
