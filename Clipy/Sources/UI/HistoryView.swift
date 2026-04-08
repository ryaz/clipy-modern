import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: ClipStore
    @State private var searchText = ""
    @State private var smartResults: [UUID]? = nil
    @State private var isSearching = false

    private var displayedClips: [ClipItem] {
        if let ids = smartResults { return ids.compactMap { id in store.clips.first { $0.id == id } } }
        if !searchText.isEmpty {
            return store.clips.filter {
                $0.displayTitle.localizedCaseInsensitiveContains(searchText) ||
                $0.aiTags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        return store.clips
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: isSearching ? "sparkle.magnifyingglass" : "magnifyingglass")
                    .foregroundStyle(isSearching ? .blue : .secondary).font(.system(size: 13))
                TextField("Search or ask a question…", text: $searchText)
                    .textFieldStyle(.plain).font(.system(size: 13))
                    .onSubmit { triggerSmartSearch() }
                    .onChange(of: searchText) { _, new in if new.isEmpty { smartResults = nil } }
                if !searchText.isEmpty {
                    Button { searchText = ""; smartResults = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain)
                }
            }.padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            if displayedClips.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 32)).foregroundStyle(.tertiary)
                    Text(searchText.isEmpty ? "No history yet" : "No results").foregroundStyle(.secondary).font(.system(size: 13))
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(displayedClips, id: \.id) { clip in
                    ClipRowView(clip: clip)
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .listRowSeparator(.hidden)
                        .onTapGesture { paste(clip) }
                        .contextMenu {
                            Button(clip.isPinned ? "Unpin" : "Pin") { store.pin(clip, pinned: !clip.isPinned) }
                            Divider()
                            Button("Delete", role: .destructive) { store.delete(clip) }
                        }
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
            Divider()
            HStack {
                Button("Clear All") { store.clearAll() }.foregroundStyle(.red).font(.system(size: 12)).buttonStyle(.plain)
                Spacer()
                Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: {
                    Image(systemName: "gear")
                }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.padding(.horizontal, 12).padding(.vertical, 6)
        }.frame(width: 340, height: 500)
    }

    private func paste(_ clip: ClipItem) { NSApp.keyWindow?.close(); PasteEngine.paste(item: clip) }

    private func triggerSmartSearch() {
        guard !searchText.isEmpty, AIService.shared.hasAPIKey else { return }
        isSearching = true
        Task {
            let ids = await AIService.shared.smartSearch(query: searchText, in: store.clips)
            await MainActor.run { smartResults = ids.isEmpty ? nil : ids; isSearching = false }
        }
    }
}

struct ClipRowView: View {
    let clip: ClipItem
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Group {
                switch clip.clipType {
                case .image:
                    if let img = clip.thumbnailImage {
                        Image(nsImage: img).resizable().scaledToFill().frame(width: 32, height: 32).clipShape(RoundedRectangle(cornerRadius: 4))
                    } else { icon("photo") }
                case .colorCode:
                    RoundedRectangle(cornerRadius: 4).fill(Color(hex: clip.stringValue) ?? .gray).frame(width: 32, height: 32)
                case .fileURL: icon("doc")
                case .url:     icon("link")
                default:       icon("doc.plaintext")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.displayTitle).font(.system(size: 13)).lineLimit(2)
                HStack(spacing: 4) {
                    if clip.isPinned { pill("📌", .orange) }
                    ForEach(clip.aiTags.prefix(3), id: \.self) { pill($0, .blue) }
                    if let app = clip.sourceAppName { Text(app).font(.system(size: 10)).foregroundStyle(.tertiary) }
                }
            }
            Spacer()
            Text(clip.updatedAt.relativeShort).font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(.vertical, 4).padding(.horizontal, 6).background(Color.primary.opacity(0.03)).clipShape(RoundedRectangle(cornerRadius: 6))
    }
    private func icon(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 14)).foregroundStyle(.secondary).frame(width: 32, height: 32)
    }
    private func pill(_ text: String, _ color: Color) -> some View {
        Text(text).font(.system(size: 9)).padding(.horizontal, 5).padding(.vertical, 2)
            .background(color.opacity(0.15)).foregroundStyle(color).clipShape(Capsule())
    }
}

extension Date {
    var relativeShort: String {
        let d = Date.now.timeIntervalSince(self)
        if d < 60 { return "now" }; if d < 3600 { return "\(Int(d/60))m" }
        if d < 86400 { return "\(Int(d/3600))h" }; return "\(Int(d/86400))d"
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        if s.count == 6 {
            self.init(red: Double((rgb >> 16) & 0xFF) / 255,
                      green: Double((rgb >> 8) & 0xFF) / 255,
                      blue: Double(rgb & 0xFF) / 255)
        } else {
            self.init(red: Double((rgb >> 24) & 0xFF) / 255,
                      green: Double((rgb >> 16) & 0xFF) / 255,
                      blue: Double((rgb >> 8) & 0xFF) / 255,
                      opacity: Double(rgb & 0xFF) / 255)
        }
    }
}
