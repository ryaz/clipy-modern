import AppKit

enum PasteEngine {
    @MainActor static func paste(item: ClipItem) {
        let pb = NSPasteboard.general; pb.clearContents()
        switch item.clipType {
        case .plainText, .url, .colorCode: pb.setString(item.stringValue, forType: .string)
        case .rtf:
            if let d = item.rtfData { pb.setData(d, forType: .rtf) }
            if !item.stringValue.isEmpty { pb.setString(item.stringValue, forType: .string) }
        case .html: if let h = item.htmlString { pb.setString(h, forType: .html) }
        case .fileURL: if let s = item.fileURLString, let u = URL(string: s) { pb.writeObjects([u as NSURL]) }
        case .image: if let d = item.imageData, let img = NSImage(data: d) { pb.writeObjects([img]) }
        case .unknown: if !item.stringValue.isEmpty { pb.setString(item.stringValue, forType: .string) }
        }
        injectCmdV()
    }

    @MainActor static func paste(string: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(string, forType: .string); injectCmdV()
    }

    private static func injectCmdV() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            let v: CGKeyCode = 9
            let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
            down?.flags = .maskCommand; down?.post(tap: .cgAnnotatedSessionEventTap)
            let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
            up?.flags = .maskCommand; up?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
