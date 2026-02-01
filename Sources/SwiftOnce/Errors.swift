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
}
