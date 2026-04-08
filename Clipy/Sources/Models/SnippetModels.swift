import Foundation
import SwiftData

@Model final class SnippetFolder {
    @Attribute(.unique) var id: UUID
    var title: String
    var index: Int
    @Relationship(deleteRule: .cascade) var items: [SnippetItem]
    init(title: String, index: Int = 0) { self.id = UUID(); self.title = title; self.index = index; self.items = [] }
}

@Model final class SnippetItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var content: String
    var index: Int
    var shortcut: String?
    init(title: String, content: String, index: Int = 0, shortcut: String? = nil) {
        self.id = UUID(); self.title = title; self.content = content; self.index = index; self.shortcut = shortcut
    }
}
