import Foundation
import SwiftData
import AppKit

enum ClipType: String, Codable, CaseIterable {
    case plainText = "public.utf8-plain-text"
    case rtf       = "public.rtf"
    case html      = "public.html"
    case image     = "public.tiff"
    case fileURL   = "public.file-url"
    case url       = "public.url"
    case colorCode = "color-code"
    case unknown   = "unknown"

    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .rtf:       return "Rich Text"
        case .html:      return "HTML"
        case .image:     return "Image"
        case .fileURL:   return "File"
        case .url:       return "URL"
        case .colorCode: return "Color"
        case .unknown:   return "Other"
        }
    }
}

@Model
final class ClipItem {
    @Attribute(.unique) var id: UUID
    var primaryType: String
    var stringValue: String
    var rtfData: Data?
    var htmlString: String?
    var imageData: Data?
    var fileURLString: String?
    var urlString: String?
    var contentHash: String
    var createdAt: Date
    var updatedAt: Date
    var sourceAppBundleID: String?
    var sourceAppName: String?
    var aiTagsJSON: String
    var aiSummary: String?
    var aiIsProcessed: Bool
    var isPinned: Bool

    init(id: UUID = UUID(), primaryType: ClipType, stringValue: String = "",
         rtfData: Data? = nil, htmlString: String? = nil, imageData: Data? = nil,
         fileURLString: String? = nil, urlString: String? = nil,
         contentHash: String, sourceAppBundleID: String? = nil, sourceAppName: String? = nil) {
        self.id = id
        self.primaryType = primaryType.rawValue
        self.stringValue = stringValue
        self.rtfData = rtfData
        self.htmlString = htmlString
        self.imageData = imageData
        self.fileURLString = fileURLString
        self.urlString = urlString
        self.contentHash = contentHash
        self.createdAt = Date()
        self.updatedAt = Date()
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.aiTagsJSON = "[]"
        self.aiIsProcessed = false
        self.isPinned = false
    }

    var clipType: ClipType { ClipType(rawValue: primaryType) ?? .unknown }

    var displayTitle: String {
        if let summary = aiSummary, !summary.isEmpty { return summary }
        if !stringValue.isEmpty { return String(stringValue.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) }
        if let url = urlString { return url }
        if let file = fileURLString { return URL(string: file)?.lastPathComponent ?? file }
        if imageData != nil { return "Image" }
        return clipType.displayName
    }

    var aiTags: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(aiTagsJSON.utf8))) ?? []
    }

    var thumbnailImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    func setAITags(_ tags: [String]) {
        if let encoded = try? JSONEncoder().encode(tags), let str = String(data: encoded, encoding: .utf8) {
            aiTagsJSON = str
        }
    }
}
