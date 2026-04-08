import AppKit
import SwiftUI

@MainActor final class MenuBarController: NSObject {
    static let shared = MenuBarController()
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem?.button {
            btn.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clipy")
            btn.action = #selector(statusButtonClicked); btn.target = self
        }
        let p = NSPopover(); p.contentSize = NSSize(width: 340, height: 500); p.behavior = .transient; p.animates = false
        p.contentViewController = NSHostingController(rootView: HistoryView().environmentObject(ClipStore.shared))
        self.popover = p
    }

    func toggleHistoryPopover() {
        guard let btn = statusItem?.button else { return }
        if let p = popover, p.isShown { p.performClose(nil); removeEventMonitor() }
        else { popover?.show(relativeTo: btn.bounds, of: btn, preferredEdge: .minY); addEventMonitor() }
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
        statusItem?.button?.menu = menu; statusItem?.button?.performClick(nil); statusItem?.button?.menu = nil
    }

    @objc private func snippetClicked(_ s: NSMenuItem) {
        guard let c = s.representedObject as? String else { return }; PasteEngine.paste(string: c)
    }
    @objc private func statusButtonClicked() { toggleHistoryPopover() }
    private func addEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.popover?.performClose(nil); self?.removeEventMonitor()
        }
    }
    private func removeEventMonitor() { if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil } }
}
