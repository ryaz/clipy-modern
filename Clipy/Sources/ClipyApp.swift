import SwiftUI

@main
struct ClipyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            Text("Clipy Settings")
                .frame(width: 400, height: 300)
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status item directly in the delegate so it's retained
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            let img = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "Clipy")
            img?.isTemplate = true
            btn.image = img
            btn.action = #selector(statusBarClicked)
            btn.target = self
        }
        HotkeyService.shared.register()
        ClipStore.shared.loadSnippets()
        Task { await ClipService.shared.startMonitoring() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.unregister()
        Task { await ClipService.shared.stopMonitoring() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    @objc private func statusBarClicked() {
        MenuBarController.shared.showHistoryMenu()
    }
}
