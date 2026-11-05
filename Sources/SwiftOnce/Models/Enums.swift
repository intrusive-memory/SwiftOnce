import Foundation

// MARK: - TTS Models

/// An ElevenLabs TTS model id. Known models are static members; any other
/// id (a model ElevenLabs ships after this release) can be passed through
/// with `Model("eleven_future")` or `Model(rawValue:)`.
public struct Model: RawRepresentable, Hashable, Sendable, Codable, Identifiable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ id: String) { self.rawValue = id }
    public init(stringLiteral value: String) { self.rawValue = value }

    public init(from decoder: any Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var id: String { rawValue }

    public static let v4 = Model("eleven_v4")
    public static let v4Turbo = Model("eleven_v4_turbo")
    public static let v3 = Model("eleven_v3")
    public static let v3Conversational = Model("eleven_v3_conversational")
    public static let multilingualV2 = Model("eleven_multilingual_v2")
    public static let flashV2_5 = Model("eleven_flash_v2_5")
    public static let turboV2_5 = Model("eleven_turbo_v2_5")
    public static let turboV2 = Model("eleven_turbo_v2")
    public static let flashV2 = Model("eleven_flash_v2")
    public static let multilingualV1 = Model("eleven_multilingual_v1")
    public static let monolingualV1 = Model("eleven_monolingual_v1")

    /// Models known to this release (excludes passthrough ids).
    public static let allCases: [Model] = [
        .v4, .v4Turbo, .v3, .v3Conversational, .multilingualV2, .flashV2_5,
        .turboV2_5, .turboV2, .flashV2, .multilingualV1, .monolingualV1,
    ]

    public var displayName: String {
        switch rawValue {
        case "eleven_v4": "Eleven v4"
        case "eleven_v4_turbo": "Eleven v4 Turbo"
        case "eleven_v3": "Eleven v3"
        case "eleven_v3_conversational": "Eleven v3 Conversational"
        case "eleven_multilingual_v2": "Multilingual v2"
        case "eleven_flash_v2_5": "Flash v2.5"
        case "eleven_turbo_v2_5": "Turbo v2.5"
        case "eleven_turbo_v2": "Turbo v2"
        case "eleven_flash_v2": "Flash v2"
        case "eleven_multilingual_v1": "Multilingual v1"
        case "eleven_monolingual_v1": "Monolingual v1"
        default: rawValue
        }
    }

    public var isLegacy: Bool {
        switch rawValue {
        case "eleven_turbo_v2", "eleven_flash_v2", "eleven_multilingual_v1", "eleven_monolingual_v1": true
        default: false
        }
    }

    /// True for ids this release does not know (passthrough).
    public var isPassthrough: Bool { !Model.allCases.contains(self) }

    /// Per-request character limit from `GET /v1/models` (2026-11-04 audit).
    /// `nil` for retired or unknown models: no client-side check is made.
    public var maxTextLength: Int? {
        switch rawValue {
        case "eleven_v4", "eleven_v4_turbo", "eleven_multilingual_v2": 10_000
        case "eleven_v3", "eleven_v3_conversational": 5_000
        case "eleven_flash_v2_5", "eleven_turbo_v2_5": 40_000
        case "eleven_turbo_v2", "eleven_flash_v2": 30_000
        default: nil
        }
    }
}

// MARK: - Output Formats

public enum OutputFormat: String, Sendable, CaseIterable {
    // MP3
    case mp3_22050_32
    case mp3_24000_48
    case mp3_44100_32
    case mp3_44100_64
    case mp3_44100_96
    case mp3_44100_128
    case mp3_44100_192
    // PCM (16-bit, little-endian)
    case pcm_8000
    case pcm_16000
    case pcm_22050
    case pcm_24000
    case pcm_32000
    case pcm_44100
    case pcm_48000
    // Opus
    case opus_48000_32
    case opus_48000_64
    case opus_48000_96
    case opus_48000_128
    case opus_48000_192
    // mu-law / A-law
    case ulaw_8000
    case alaw_8000
    // WAV
    case wav_8000
    case wav_16000
    case wav_22050
    case wav_24000
    case wav_32000
    case wav_44100
    case wav_48000

    public var mimeType: String {
        switch self {
        case _ where rawValue.hasPrefix("mp3"): "audio/mpeg"
        case _ where rawValue.hasPrefix("pcm"): "audio/pcm"
        case _ where rawValue.hasPrefix("opus"): "audio/opus"
        case _ where rawValue.hasPrefix("ulaw"): "audio/basic"
        case _ where rawValue.hasPrefix("alaw"): "audio/basic"
        case _ where rawValue.hasPrefix("wav"): "audio/wav"
        default: "application/octet-stream"
        }
    }

    public var fileExtension: String {
        switch self {
        case _ where rawValue.hasPrefix("mp3"): "mp3"
        case _ where rawValue.hasPrefix("pcm"): "pcm"
        case _ where rawValue.hasPrefix("opus"): "opus"
        case _ where rawValue.hasPrefix("ulaw"): "ulaw"
        case _ where rawValue.hasPrefix("alaw"): "alaw"
        case _ where rawValue.hasPrefix("wav"): "wav"
        default: "bin"
        }
    }
}

// MARK: - Voice Category

public enum VoiceCategory: String, Sendable, Codable {
    case premade
    case cloned
    case generated
    case professional
    case famous
    case highQuality = "high_quality"
}

// MARK: - Voice Type Filter

public enum VoiceType: String, Sendable {
    case personal
    case community
    case `default`
    case workspace
    case nonDefault = "non-default"
    case saved
}

// MARK: - Text Normalization

public enum TextNormalization: String, Sendable, Codable {
    case auto
    case on
    case off
}

// MARK: - Streaming Latency

public enum StreamingLatencyOptimization: Int, Sendable {
    case none = 0
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
}

// MARK: - Voice Sort

public enum VoiceSortField: String, Sendable {
    case createdAt = "created_at_unix"
    case name = "name"
}

public enum SortDirection: String, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

// MARK: - Voice Design Models

public enum VoiceDesignModel: String, Sendable {
    case v2 = "eleven_multilingual_ttv_v2"
    case v3 = "eleven_ttv_v3"
}
