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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MenuBarController.shared.setup()
        HotkeyService.shared.register()
        ClipStore.shared.loadSnippets()
        Task { await ClipService.shared.startMonitoring() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyService.shared.unregister()
        Task { await ClipService.shared.stopMonitoring() }
    }
}
