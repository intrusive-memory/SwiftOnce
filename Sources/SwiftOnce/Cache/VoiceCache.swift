import Foundation

actor VoiceCache {
    private struct Entry {
        let response: VoiceListResponse
        let timestamp: Date
    }

    private var entries: [String: Entry] = [:]
    private var voiceIndex: [String: Voice] = [:]
    private let ttl: TimeInterval

    init(ttl: TimeInterval) {
        self.ttl = ttl
    }

    func get(key: String) -> VoiceListResponse? {
        guard let entry = entries[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > ttl {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.response
    }

    func set(key: String, value: VoiceListResponse) {
        entries[key] = Entry(response: value, timestamp: Date())
        for voice in value.voices {
            voiceIndex[voice.voiceId] = voice
        }
    }

    func getVoice(_ id: String) -> Voice? {
        voiceIndex[id]
    }

    func invalidate() {
        entries.removeAll()
        voiceIndex.removeAll()
    }
}
