import Foundation

public struct TimestampedAudio: Sendable {
    public let audioData: Data
    public let alignment: Alignment?
    public let normalizedAlignment: Alignment?

    public struct Alignment: Sendable, Codable {
        public let characters: [String]
        public let characterStartTimesSeconds: [Double]
        public let characterEndTimesSeconds: [Double]

        enum CodingKeys: String, CodingKey {
            case characters
            case characterStartTimesSeconds = "character_start_times_seconds"
            case characterEndTimesSeconds = "character_end_times_seconds"
        }
    }
}

public struct TimestampedChunk: Sendable {
    public let audioData: Data?
    public let alignment: TimestampedAudio.Alignment?
    public let normalizedAlignment: TimestampedAudio.Alignment?
}

// MARK: - Internal JSON DTO

struct TimestampedResponseDTO: Codable {
    let audioBase64: String?
    let alignment: TimestampedAudio.Alignment?
    let normalizedAlignment: TimestampedAudio.Alignment?

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base64"
        case alignment
        case normalizedAlignment = "normalized_alignment"
    }
}
