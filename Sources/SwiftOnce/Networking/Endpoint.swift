import Foundation

enum Endpoint {
    case textToSpeech(voiceId: String)
    case textToSpeechStream(voiceId: String)
    case textToSpeechWithTimestamps(voiceId: String)
    case textToSpeechStreamWithTimestamps(voiceId: String)
    case voices
    case voice(voiceId: String)
    case voiceDesign
    case createVoice
    case deleteVoice(voiceId: String)
    case models
    case subscription

    var path: String {
        switch self {
        case .textToSpeech(let voiceId):
            "/v1/text-to-speech/\(voiceId)"
        case .textToSpeechStream(let voiceId):
            "/v1/text-to-speech/\(voiceId)/stream"
        case .textToSpeechWithTimestamps(let voiceId):
            "/v1/text-to-speech/\(voiceId)/with-timestamps"
        case .textToSpeechStreamWithTimestamps(let voiceId):
            "/v1/text-to-speech/\(voiceId)/stream/with-timestamps"
        case .voices:
            "/v2/voices"
        case .voice(let voiceId):
            "/v1/voices/\(voiceId)"
        case .voiceDesign:
            "/v1/text-to-voice/design"
        case .createVoice:
            "/v1/text-to-voice"
        case .deleteVoice(let voiceId):
            "/v1/voices/\(voiceId)"
        case .models:
            "/v1/models"
        case .subscription:
            "/v1/user/subscription"
        }
    }

    var method: String {
        switch self {
        case .textToSpeech, .textToSpeechStream,
             .textToSpeechWithTimestamps, .textToSpeechStreamWithTimestamps:
            "POST"
        case .voiceDesign, .createVoice:
            "POST"
        case .voices, .voice, .models, .subscription:
            "GET"
        case .deleteVoice:
            "DELETE"
        }
    }

    func urlRequest(
        baseURL: URL,
        apiKey: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        userAgent: String? = nil
    ) -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        if let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }

        return request
    }
}
