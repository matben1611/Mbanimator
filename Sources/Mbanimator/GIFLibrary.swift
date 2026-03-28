import Foundation
import AppKit

class GIFLibrary: ObservableObject {
    @Published var entries: [GIFEntry] = []
    private let key = "gif_library"

    init() {
        let saved = UserDefaults.standard.stringArray(forKey: key) ?? []
        entries = saved.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return GIFEntry(path: path, name: url.deletingPathExtension().lastPathComponent)
        }
    }

    func add(url: URL) {
        let path = url.path
        guard !entries.contains(where: { $0.path == path }) else { return }
        entries.append(GIFEntry(path: path, name: url.deletingPathExtension().lastPathComponent))
        save()
    }

    func remove(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        UserDefaults.standard.set(entries.map(\.path), forKey: key)
    }
}

struct GIFEntry: Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let thumbnail: NSImage?

    init(path: String, name: String) {
        self.path = path
        self.name = name
        self.thumbnail = Self.loadThumbnail(from: path)
    }

    private static func loadThumbnail(from path: String) -> NSImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let rep = NSBitmapImageRep(data: data),
              let cgImage = rep.cgImage else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: 40, height: 40))
    }
}
