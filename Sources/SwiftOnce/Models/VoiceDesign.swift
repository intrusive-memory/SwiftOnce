import Foundation

// MARK: - Public Types

public struct VoicePreview: Sendable, Identifiable {
    public let id: String
    public let audioData: Data
    public let mediaType: String
    public let duration: TimeInterval
    public let language: String?
}

public struct VoiceDesignResponse: Sendable {
    public let previews: [VoicePreview]
    public let text: String
}

// MARK: - Internal DTOs

struct VoiceDesignResponseDTO: Codable {
    let previews: [VoicePreviewDTO]
    let text: String
}

struct VoicePreviewDTO: Codable {
    let audioBase64: String
    let generatedVoiceId: String
    let mediaType: String
    let durationSecs: Double
    let language: String?

    enum CodingKeys: String, CodingKey {
        case audioBase64 = "audio_base_64"
        case generatedVoiceId = "generated_voice_id"
        case mediaType = "media_type"
        case durationSecs = "duration_secs"
        case language
    }
}
