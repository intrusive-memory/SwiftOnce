import Foundation
import CryptoKit

actor AudioCache {
    private struct IndexEntry {
        let fileURL: URL
        let size: Int64
        var lastAccess: Date
    }

    private let directory: URL
    private let maxBytes: Int64
    private var index: [String: IndexEntry] = [:]
    private var loaded = false

    init(directory: URL?, maxBytes: Int64) {
        if let directory {
            self.directory = directory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.directory = caches.appendingPathComponent("SwiftOnce", isDirectory: true)
        }
        self.maxBytes = maxBytes
    }

    func get(key: String) throws -> Data? {
        try ensureLoaded()
        guard var entry = index[key] else { return nil }
        guard FileManager.default.fileExists(atPath: entry.fileURL.path) else {
            index.removeValue(forKey: key)
            return nil
        }
        entry.lastAccess = Date()
        index[key] = entry
        return try Data(contentsOf: entry.fileURL)
    }

    func set(key: String, data: Data) throws {
        try ensureLoaded()
        try ensureDirectory()

        let fileURL = directory.appendingPathComponent("\(key).audio")
        try data.write(to: fileURL)

        index[key] = IndexEntry(
            fileURL: fileURL,
            size: Int64(data.count),
            lastAccess: Date()
        )

        try evictIfNeeded()
    }

    func clear() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            try fm.removeItem(at: directory)
        }
        index.removeAll()
    }

    func totalSize() throws -> Int64 {
        try ensureLoaded()
        return index.values.reduce(0) { $0 + $1.size }
    }

    // MARK: - Internal

    private func ensureDirectory() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directory.path) {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private func ensureLoaded() throws {
        guard !loaded else { return }
        loaded = true

        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return }

        let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey])
        for fileURL in files where fileURL.pathExtension == "audio" {
            let key = fileURL.deletingPathExtension().lastPathComponent
            let attrs = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey])
            let size = Int64(attrs.fileSize ?? 0)
            let lastAccess = attrs.contentAccessDate ?? Date.distantPast
            index[key] = IndexEntry(fileURL: fileURL, size: size, lastAccess: lastAccess)
        }
    }

    private func evictIfNeeded() throws {
        var total = index.values.reduce(Int64(0)) { $0 + $1.size }
        guard total > maxBytes else { return }

        let target = Int64(Double(maxBytes) * 0.8)
        let sorted = index.sorted { $0.value.lastAccess < $1.value.lastAccess }

        for (key, entry) in sorted {
            guard total > target else { break }
            try? FileManager.default.removeItem(at: entry.fileURL)
            total -= entry.size
            index.removeValue(forKey: key)
        }
    }

    // MARK: - Key Generation

    static func cacheKey(text: String, voiceId: String, model: Model, outputFormat: OutputFormat, settings: VoiceSettings?) -> String {
        var input = "\(text)|\(voiceId)|\(model.rawValue)|\(outputFormat.rawValue)"
        if let settings {
            input += "|\(settings.stability)|\(settings.similarityBoost)"
            if let style = settings.style { input += "|\(style)" }
            if let speed = settings.speed { input += "|\(speed)" }
            if let boost = settings.useSpeakerBoost { input += "|\(boost)" }
        }
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
