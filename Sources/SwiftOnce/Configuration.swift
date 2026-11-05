import Foundation

public struct SwiftOnceConfiguration: Sendable {
    public var baseURL: URL
    public var userAgent: String?
    public var voiceCacheTTL: TimeInterval
    public var audioCacheDirectory: URL?
    public var audioCacheMaxBytes: Int64
    public var defaultModel: Model
    public var defaultOutputFormat: OutputFormat
    /// Voice-design model sent with `designVoice` when none is given.
    public var defaultDesignModel: VoiceDesignModel
    public var enableLogging: Bool
    public var defaultVoiceId: String?
    public var defaultVoiceName: String?
    /// Maximum concurrent API requests. ElevenLabs limits by tier:
    /// Free: 2, Starter: 3, Creator: 5, Pro: 10, Scale: 15, Business: 15.
    /// Default is 2 (safe for every tier, including Free); raise it for your plan.
    public var maxConcurrentRequests: Int
    /// Maximum retry attempts on HTTP 429, 5xx (and 409 on voice design/create).
    /// Jittered exponential backoff, or the Retry-After header when present.
    public var maxRetries: Int

    public init(
        baseURL: URL = URL(string: "https://api.elevenlabs.io")!,
        userAgent: String? = nil,
        voiceCacheTTL: TimeInterval = 300,
        audioCacheDirectory: URL? = nil,
        audioCacheMaxBytes: Int64 = 500_000_000,
        defaultModel: Model = .v4,
        defaultOutputFormat: OutputFormat = .mp3_44100_128,
        defaultDesignModel: VoiceDesignModel = .v2,
        enableLogging: Bool = false,
        defaultVoiceId: String? = ElevenLabsDefaults.defaultVoiceId,
        defaultVoiceName: String? = "narrator",
        maxConcurrentRequests: Int = 2,
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.voiceCacheTTL = voiceCacheTTL
        self.audioCacheDirectory = audioCacheDirectory
        self.audioCacheMaxBytes = audioCacheMaxBytes
        self.defaultModel = defaultModel
        self.defaultOutputFormat = defaultOutputFormat
        self.defaultDesignModel = defaultDesignModel
        self.enableLogging = enableLogging
        self.defaultVoiceId = defaultVoiceId
        self.defaultVoiceName = defaultVoiceName
        self.maxConcurrentRequests = maxConcurrentRequests
        self.maxRetries = maxRetries
    }
}
