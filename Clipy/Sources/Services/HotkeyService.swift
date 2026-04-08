import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let openHistory  = Self("openHistory",  default: .init(.v, modifiers: [.command, .shift]))
    static let openSnippets = Self("openSnippets", default: .init(.b, modifiers: [.command, .shift]))
}

final class HotkeyService {
    static let shared = HotkeyService()
    private init() {}
    func register() {
        KeyboardShortcuts.onKeyDown(for: .openHistory)  { Task { @MainActor in MenuBarController.shared.showHistoryMenu() } }
        KeyboardShortcuts.onKeyDown(for: .openSnippets) { Task { @MainActor in MenuBarController.shared.toggleSnippetMenu() } }
    }
    func unregister() { KeyboardShortcuts.disable(.openHistory); KeyboardShortcuts.disable(.openSnippets) }
}
