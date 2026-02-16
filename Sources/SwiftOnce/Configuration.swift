import Foundation

public struct SwiftOnceConfiguration: Sendable {
    public var baseURL: URL
    public var userAgent: String?
    public var voiceCacheTTL: TimeInterval
    public var audioCacheDirectory: URL?
    public var audioCacheMaxBytes: Int64
    public var defaultModel: Model
    public var defaultOutputFormat: OutputFormat
    public var enableLogging: Bool
    public var defaultVoiceId: String?
    public var defaultVoiceName: String?
    /// Maximum concurrent API requests. ElevenLabs limits by tier:
    /// Free: 2, Starter: 3, Creator: 5, Pro: 10, Scale: 15, Business: 15.
    /// Default is 8 (safe for Pro tier).
    public var maxConcurrentRequests: Int
    /// Maximum retry attempts on rate-limit (HTTP 429) responses.
    /// Uses exponential backoff with the Retry-After header when available.
    public var maxRetries: Int

    public init(
        baseURL: URL = URL(string: "https://api.elevenlabs.io")!,
        userAgent: String? = nil,
        voiceCacheTTL: TimeInterval = 300,
        audioCacheDirectory: URL? = nil,
        audioCacheMaxBytes: Int64 = 500_000_000,
        defaultModel: Model = .multilingualV2,
        defaultOutputFormat: OutputFormat = .mp3_44100_128,
        enableLogging: Bool = false,
        defaultVoiceId: String? = ElevenLabsDefaults.defaultVoiceId,
        defaultVoiceName: String? = "narrator",
        maxConcurrentRequests: Int = 8,
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.userAgent = userAgent
        self.voiceCacheTTL = voiceCacheTTL
        self.audioCacheDirectory = audioCacheDirectory
        self.audioCacheMaxBytes = audioCacheMaxBytes
        self.defaultModel = defaultModel
        self.defaultOutputFormat = defaultOutputFormat
        self.enableLogging = enableLogging
        self.defaultVoiceId = defaultVoiceId
        self.defaultVoiceName = defaultVoiceName
        self.maxConcurrentRequests = maxConcurrentRequests
        self.maxRetries = maxRetries
    }
}
