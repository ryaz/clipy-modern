import Foundation
import AppKit
import os

private let logger = Logger(subsystem: "com.ryaz.clipy-modern", category: "ClipService")

@MainActor
final class ClipService {
    static let shared = ClipService()
    private var dispatchTimer: DispatchSourceTimer?
    private var lastChangeCount: Int = 0
    private var activityToken: NSObjectProtocol?
    private var pollCount: UInt64 = 0

    func startMonitoring() {
        stopMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        logger.info("Starting clipboard monitoring, initial changeCount=\(self.lastChangeCount)")

        ProcessInfo.processInfo.disableAutomaticTermination("Clipboard monitoring")
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Clipboard monitoring"
        )

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(750))
        timer.setEventHandler { [weak self] in
            self?.checkPasteboard()
        }
        timer.resume()
        dispatchTimer = timer
    }

    func stopMonitoring() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    private func checkPasteboard() {
        pollCount += 1
        if pollCount % 400 == 0 {
            logger.debug("Poll heartbeat #\(self.pollCount), lastChangeCount=\(self.lastChangeCount)")
        }

        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        logger.info("Pasteboard changed: \(self.lastChangeCount) → \(current)")
        lastChangeCount = current

        if ExcludeAppService.shared.frontProcessIsExcluded() {
            logger.info("Skipping — front app is excluded")
            return
        }
        createClip(from: NSPasteboard.general)
    }

    private func createClip(from pasteboard: NSPasteboard) {
        guard let item = buildClipItem(from: pasteboard) else {
            logger.warning("buildClipItem returned nil — pasteboard had no usable content")
            return
        }
        logger.info("Saving clip: type=\(item.primaryType), hash=\(item.contentHash.prefix(8))")
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
