import Foundation

public enum ElevenLabsError: Error, Sendable {
    case invalidAPIKey
    case httpError(statusCode: Int, body: String?)
    case rateLimited(retryAfterSeconds: Int?)
    case quotaExceeded
    case voiceNotFound(String)
    case invalidRequest(String)
    case decodingError(any Error)
    case networkError(any Error)
    case cachingError(any Error)
    case defaultVoiceNotFound(String)
    /// The account's voice-slot limit is reached (from the error body's `detail.status`).
    case voiceLimitReached(String?)
    /// Client-side check: `text` has `count` characters, over `limit` for `model`.
    case textTooLong(model: String, limit: Int, count: Int)
    /// Client-side check: voice design `text` must be 100...1000 characters.
    case invalidDesignText(count: Int)
}
