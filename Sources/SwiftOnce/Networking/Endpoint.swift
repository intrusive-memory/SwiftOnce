import Foundation

enum Endpoint {
    case textToSpeech(voiceId: String)
    case textToSpeechStream(voiceId: String)
    case textToSpeechWithTimestamps(voiceId: String)
    case textToSpeechStreamWithTimestamps(voiceId: String)
    case voices
    case voice(voiceId: String)

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
        }
    }

    var method: String {
        switch self {
        case .textToSpeech, .textToSpeechStream,
             .textToSpeechWithTimestamps, .textToSpeechStreamWithTimestamps:
            "POST"
        case .voices, .voice:
            "GET"
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
