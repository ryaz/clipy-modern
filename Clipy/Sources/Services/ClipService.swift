import Foundation
import AppKit
import SwiftData

@MainActor
final class ClipService {
    static let shared = ClipService()
    private var timer: Timer?
    private var lastChangeCount: Int = 0

    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        ProcessInfo.processInfo.disableAutomaticTermination("Clipboard monitoring")
        if #available(macOS 12, *) {
            ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Clipboard monitoring"
            )
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPasteboard() }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        guard !ExcludeAppService.shared.frontProcessIsExcluded() else { return }
        createClip(from: NSPasteboard.general)
    }

    private func createClip(from pasteboard: NSPasteboard) {
        guard let item = buildClipItem(from: pasteboard) else { return }
        ClipStore.shared.save(item)
        Task { await AIService.shared.process(item) }
    }

    private func buildClipItem(from pasteboard: NSPasteboard) -> ClipItem? {
        if let image = NSImage(pasteboard: pasteboard), let png = image.pngData() {
            return ClipItem(primaryType: .image, imageData: png, contentHash: ClipStore.sha256(png),
                            sourceAppBundleID: frontAppBundleID(), sourceAppName: frontAppName())
        }
        if let urlStr = pasteboard.string(forType: .fileURL) {
            return ClipItem(primaryType: .fileURL, stringValue: URL(string: urlStr)?.path ?? urlStr,
                            fileURLString: urlStr, contentHash: ClipStore.sha256(urlStr),
                            sourceAppBundleID: frontAppBundleID(), sourceAppName: frontAppName())
        }
        if let rtfData = pasteboard.data(forType: .rtf) {
            let plain = NSAttributedString(rtf: rtfData, documentAttributes: nil)?.string ?? ""
            guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ClipItem(primaryType: .rtf, stringValue: plain, rtfData: rtfData,
                            contentHash: ClipStore.sha256(plain),
                            sourceAppBundleID: frontAppBundleID(), sourceAppName: frontAppName())
        }
        if let text = pasteboard.string(forType: .string) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let isColor = trimmed.range(of: #"^#[0-9A-Fa-f]{3,8}$"#, options: .regularExpression) != nil
            return ClipItem(primaryType: isColor ? .colorCode : .plainText, stringValue: trimmed,
                            contentHash: ClipStore.sha256(trimmed),
                            sourceAppBundleID: frontAppBundleID(), sourceAppName: frontAppName())
        }
        return nil
    }

    private func frontAppBundleID() -> String? { NSWorkspace.shared.frontmostApplication?.bundleIdentifier }
    private func frontAppName() -> String? { NSWorkspace.shared.frontmostApplication?.localizedName }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
