import AppKit
import SwiftUI

@MainActor final class MenuBarController: NSObject {
    static let shared = MenuBarController()

    func showHistoryMenu() {
        PasteEngine.savePreviousApp()

        let menu = NSMenu(title: "Clipy History")
        let clips = ClipStore.shared.clips

        if clips.isEmpty {
            menu.addItem(NSMenuItem(title: "No items", action: nil, keyEquivalent: ""))
        } else {
            for (i, clip) in clips.prefix(10).enumerated() {
                let key = i < 9 ? "\(i + 1)" : ""
                let title = "\(i + 1). \(clip.displayTitle.prefix(80))"
                let item = NSMenuItem(title: title, action: #selector(historyItemClicked(_:)), keyEquivalent: key)
                if !key.isEmpty {
                    item.keyEquivalentModifierMask = []
                }
                item.representedObject = clip
                item.target = self
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())
        let clearItem = NSMenuItem(title: "Clear All", action: #selector(clearAllClicked), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    func toggleSnippetMenu() {
        let menu = NSMenu()
        for folder in ClipStore.shared.snippets {
            let fi = NSMenuItem(title: folder.title, action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for snippet in folder.items.sorted(by: { $0.index < $1.index }) {
                let si = NSMenuItem(title: snippet.title, action: #selector(snippetClicked(_:)), keyEquivalent: snippet.shortcut ?? "")
                si.representedObject = snippet.content; si.target = self; sub.addItem(si)
            }
            fi.submenu = sub; menu.addItem(fi)
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func historyItemClicked(_ sender: NSMenuItem) {
        guard let clip = sender.representedObject as? ClipItem else { return }
        PasteEngine.paste(item: clip)
    }

    @objc private func clearAllClicked() {
        ClipStore.shared.clearAll()
    }

    @objc private func snippetClicked(_ s: NSMenuItem) {
        guard let c = s.representedObject as? String else { return }; PasteEngine.paste(string: c)
    }
}
