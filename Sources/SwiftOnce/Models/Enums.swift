import Foundation

// MARK: - TTS Models

public enum Model: String, Sendable, Codable, CaseIterable, Identifiable {
    case v3 = "eleven_v3"
    case multilingualV2 = "eleven_multilingual_v2"
    case flashV2_5 = "eleven_flash_v2_5"
    case turboV2_5 = "eleven_turbo_v2_5"
    case turboV2 = "eleven_turbo_v2"
    case flashV2 = "eleven_flash_v2"
    case multilingualV1 = "eleven_multilingual_v1"
    case monolingualV1 = "eleven_monolingual_v1"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .v3: "Eleven v3 (Alpha)"
        case .multilingualV2: "Multilingual v2"
        case .flashV2_5: "Flash v2.5"
        case .turboV2_5: "Turbo v2.5"
        case .turboV2: "Turbo v2"
        case .flashV2: "Flash v2"
        case .multilingualV1: "Multilingual v1"
        case .monolingualV1: "Monolingual v1"
        }
    }

    public var isLegacy: Bool {
        switch self {
        case .turboV2, .flashV2, .multilingualV1, .monolingualV1: true
        default: false
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
