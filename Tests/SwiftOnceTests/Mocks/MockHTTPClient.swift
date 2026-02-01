import Foundation
@testable import SwiftOnce

actor MockHTTPClient: HTTPClient {
    private var responses: [(Data, URLResponse)] = []
    private(set) var capturedRequests: [URLRequest] = []
    private var callIndex = 0

    func enqueue(data: Data, statusCode: Int = 200, headerFields: [String: String]? = nil) {
        let response = HTTPURLResponse(
            url: URL(string: "https://api.elevenlabs.io")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headerFields
        )!
        responses.append((data, response))
    }

    nonisolated func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await _data(for: request)
    }

    nonisolated func bytes(for request: URLRequest) async throws -> (URLSession.AsyncBytes, URLResponse) {
        fatalError("Not implemented in mock")
    }

    private func _data(for request: URLRequest) throws -> (Data, URLResponse) {
        capturedRequests.append(request)
        guard callIndex < responses.count else {
            throw URLError(.badServerResponse)
        }
        let response = responses[callIndex]
        callIndex += 1
        return response
    }
}
