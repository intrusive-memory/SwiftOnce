import Testing
import Foundation
@testable import SwiftOnce

private actor DelayRecorder {
    var delays: [TimeInterval] = []
    func add(_ d: TimeInterval) { delays.append(d) }
}

private func config() -> SwiftOnceConfiguration {
    SwiftOnceConfiguration(
        audioCacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    )
}

private func makeClient(_ mock: MockHTTPClient, _ recorder: DelayRecorder = DelayRecorder(), config cfg: SwiftOnceConfiguration? = nil) -> SwiftOnce {
    SwiftOnce(apiKey: "secret-key-123", configuration: cfg ?? config(), httpClient: mock,
              sleeper: { await recorder.add($0) })
}

private func bodyJSON(_ request: URLRequest) -> [String: Any] {
    (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any] ?? [:]
}

// MARK: - Models

@Test func v4ModelEncodeDecode() throws {
    #expect(Model.v4.rawValue == "eleven_v4")
    #expect(Model.v4Turbo.rawValue == "eleven_v4_turbo")
    let data = try JSONEncoder().encode([Model.v4])
    #expect(String(data: data, encoding: .utf8) == "[\"eleven_v4\"]")
    let decoded = try JSONDecoder().decode([Model].self, from: Data("[\"eleven_v4_turbo\"]".utf8))
    #expect(decoded == [.v4Turbo])
    #expect(!Model.v4.isPassthrough)
}

@Test func passthroughModelIsSentVerbatim() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("audio".utf8))
    let client = makeClient(mock)
    let model = Model("eleven_future_v9")
    #expect(model.isPassthrough)
    _ = try await client.speak("Hi", voice: "v1", model: model)
    let reqs = await mock.capturedRequests
    #expect(bodyJSON(reqs[0])["model_id"] as? String == "eleven_future_v9")
}

@Test func defaultModelIsV4InBody() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("audio".utf8))
    let client = makeClient(mock)
    _ = try await client.speak("Hi", voice: "v1")
    #expect(bodyJSON(await mock.capturedRequests[0])["model_id"] as? String == "eleven_v4")
}

@Test func modelsAndSubscriptionDecode() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("""
    [{"model_id":"eleven_v4","name":"Eleven v4","can_do_text_to_speech":true,
      "maximum_text_length_per_request":10000,"can_use_style":false,
      "model_rates":{"character_cost_multiplier":1.0}}]
    """.utf8))
    await mock.enqueue(data: Data("""
    {"tier":"creator","status":"active","character_count":10,"character_limit":100,
     "voice_limit":30,"voice_slots_used":4,"next_character_count_reset_unix":1796280074}
    """.utf8))
    let client = makeClient(mock)
    let models = try await client.models()
    #expect(models[0].modelId == "eleven_v4")
    #expect(models[0].maximumTextLengthPerRequest == 10000)
    #expect(models[0].characterCostMultiplier == 1.0)
    let sub = try await client.subscription()
    #expect(sub.tier == "creator")
    #expect(sub.voiceSlotsFree == 26)
    #expect(sub.charactersRemaining == 90)
    let reqs = await mock.capturedRequests
    #expect(reqs[0].url?.path == "/v1/models")
    #expect(reqs[1].url?.path == "/v1/user/subscription")
    #expect(reqs[0].httpMethod == "GET")
}

// MARK: - Length limit

@Test func lengthLimitThrowsBeforeRequest() async {
    let mock = MockHTTPClient()
    let client = makeClient(mock)
    do {
        _ = try await client.speak(String(repeating: "a", count: 10_001), voice: "v1", model: .v4)
        #expect(Bool(false), "should throw")
    } catch let error as ElevenLabsError {
        guard case .textTooLong(let model, let limit, let count) = error else {
            #expect(Bool(false), "wrong error \(error)"); return
        }
        #expect(model == "eleven_v4" && limit == 10_000 && count == 10_001)
    } catch { #expect(Bool(false)) }
    #expect(await mock.capturedRequests.isEmpty)
}

@Test func lengthLimitIsPerModel() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("audio".utf8))
    let client = makeClient(mock)
    // 6000 chars: over v3 (5000), fine for v4 (10000)
    #expect(SwiftOnce.lengthError(String(repeating: "a", count: 6000), model: .v3) != nil)
    _ = try await client.speak(String(repeating: "a", count: 6000), voice: "v1", model: .v4)
}

// MARK: - request-id

@Test func requestIdExposed() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("audio".utf8), headerFields: ["request-id": "req_abc"])
    let client = makeClient(mock)
    let result = try await client.speakResult("Hi", voice: "v1", previousRequestIds: ["req_0"])
    #expect(result.requestId == "req_abc")
    #expect(result.audio == Data("audio".utf8))
    #expect(bodyJSON(await mock.capturedRequests[0])["previous_request_ids"] as? [String] == ["req_0"])
}

// MARK: - Retry

@Test func serverErrorRetriesThenSucceeds() async throws {
    let mock = MockHTTPClient()
    let rec = DelayRecorder()
    await mock.enqueue(data: Data("boom".utf8), statusCode: 503)
    await mock.enqueue(data: Data("boom".utf8), statusCode: 500)
    await mock.enqueue(data: Data("audio".utf8))
    let client = makeClient(mock, rec)
    let data = try await client.speak("Hi", voice: "v1")
    #expect(data == Data("audio".utf8))
    #expect(await mock.capturedRequests.count == 3)
    let delays = await rec.delays
    #expect(delays.count == 2)
    #expect(delays[0] >= 0.5 && delays[0] <= 1.0)   // jittered 1s
    #expect(delays[1] >= 1.0 && delays[1] <= 2.0)   // jittered 2s
}

@Test func serverErrorExhaustsToHttpError() async {
    let mock = MockHTTPClient()
    var cfg = config(); cfg.maxRetries = 1
    for _ in 0..<2 { await mock.enqueue(data: Data("boom".utf8), statusCode: 502) }
    let client = makeClient(mock, config: cfg)
    do {
        _ = try await client.speak("Hi", voice: "v1")
        #expect(Bool(false))
    } catch let error as ElevenLabsError {
        guard case .httpError(let code, _) = error else { #expect(Bool(false)); return }
        #expect(code == 502)
    } catch { #expect(Bool(false)) }
    #expect(await mock.capturedRequests.count == 2)
}

@Test func retryAfterIntegerHonored() async throws {
    let mock = MockHTTPClient()
    let rec = DelayRecorder()
    await mock.enqueue(data: Data(), statusCode: 429, headerFields: ["Retry-After": "7"])
    await mock.enqueue(data: Data("audio".utf8))
    _ = try await makeClient(mock, rec).speak("Hi", voice: "v1")
    #expect(await rec.delays == [7])
}

@Test func retryAfterHttpDateHonored() async throws {
    let future = Date().addingTimeInterval(30)
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "GMT")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    let mock = MockHTTPClient()
    let rec = DelayRecorder()
    await mock.enqueue(data: Data(), statusCode: 503, headerFields: ["Retry-After": f.string(from: future)])
    await mock.enqueue(data: Data("audio".utf8))
    _ = try await makeClient(mock, rec).speak("Hi", voice: "v1")
    let d = try #require(await rec.delays.first)
    #expect(d > 25 && d <= 30)
}

@Test func retryAfterParsing() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(SwiftOnce.parseRetryAfter("12", now: now) == 12)
    #expect(SwiftOnce.parseRetryAfter("garbage", now: now) == nil)
    #expect(SwiftOnce.parseRetryAfter(nil, now: now) == nil)
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "GMT")
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
    #expect(SwiftOnce.parseRetryAfter(f.string(from: now.addingTimeInterval(-100)), now: now) == 0)
}

@Test func unauthorizedIsPermanent() async {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("{\"detail\":{\"status\":\"invalid_api_key\"}}".utf8), statusCode: 401)
    await mock.enqueue(data: Data("audio".utf8))
    let rec = DelayRecorder()
    do {
        _ = try await makeClient(mock, rec).speak("Hi", voice: "v1")
        #expect(Bool(false))
    } catch let error as ElevenLabsError {
        guard case .invalidAPIKey = error else { #expect(Bool(false)); return }
        #expect(!"\(error)".contains("secret-key-123"))
    } catch { #expect(Bool(false)) }
    #expect(await mock.capturedRequests.count == 1)
    #expect(await rec.delays.isEmpty)
}

@Test func quotaBodyMapsToQuotaExceededNoRetry() async {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("{\"detail\":{\"status\":\"quota_exceeded\",\"message\":\"x\"}}".utf8), statusCode: 401)
    do {
        _ = try await makeClient(mock).speak("Hi", voice: "v1")
        #expect(Bool(false))
    } catch let error as ElevenLabsError {
        guard case .quotaExceeded = error else { #expect(Bool(false), "got \(error)"); return }
    } catch { #expect(Bool(false)) }
    #expect(await mock.capturedRequests.count == 1)
}

@Test func voiceLimitBodyMapsToVoiceLimitReached() async {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("{\"detail\":{\"status\":\"voice_limit_reached\",\"message\":\"Slots full\"}}".utf8), statusCode: 400)
    do {
        _ = try await makeClient(mock).createVoice(
            from: VoicePreview(id: "g1", audioData: Data(), mediaType: "audio/mpeg", duration: 1, language: nil),
            name: "n", description: "d")
        #expect(Bool(false))
    } catch let error as ElevenLabsError {
        guard case .voiceLimitReached(let msg) = error else { #expect(Bool(false), "got \(error)"); return }
        #expect(msg == "Slots full")
    } catch { #expect(Bool(false)) }
}

@Test func conflictRetriedOnDesignOnly() async throws {
    let mock = MockHTTPClient()
    let rec = DelayRecorder()
    await mock.enqueue(data: Data("busy".utf8), statusCode: 409)
    await mock.enqueue(data: Data("{\"previews\":[],\"text\":\"t\"}".utf8))
    let client = makeClient(mock, rec)
    let text = String(repeating: "x", count: 120)
    _ = try await client.designVoice(description: "d", previewText: text)
    #expect(await mock.capturedRequests.count == 2)

    // 409 on TTS is not retried.
    let mock2 = MockHTTPClient()
    await mock2.enqueue(data: Data("busy".utf8), statusCode: 409)
    do {
        _ = try await makeClient(mock2).speak("Hi", voice: "v1")
        #expect(Bool(false))
    } catch {}
    #expect(await mock2.capturedRequests.count == 1)
}

// MARK: - Voice delete

@Test func deleteVoiceRequestShapeAndCacheInvalidation() async throws {
    let mock = MockHTTPClient()
    let voiceJSON = "{\"voices\":[],\"has_more\":false,\"total_count\":0}"
    await mock.enqueue(data: Data(voiceJSON.utf8))            // voices() populate cache
    await mock.enqueue(data: Data("{\"status\":\"ok\"}".utf8)) // delete
    await mock.enqueue(data: Data(voiceJSON.utf8))            // voices() again must hit network
    let client = makeClient(mock)
    _ = try await client.voices()
    try await client.deleteVoice("abc123")
    _ = try await client.voices()
    let reqs = await mock.capturedRequests
    #expect(reqs.count == 3)
    #expect(reqs[1].httpMethod == "DELETE")
    #expect(reqs[1].url?.path == "/v1/voices/abc123")
    #expect(reqs[1].httpBody == nil)
    #expect(reqs[1].value(forHTTPHeaderField: "xi-api-key") == "secret-key-123")
}

// MARK: - Voice design

@Test func designTextLengthValidated() async {
    let mock = MockHTTPClient()
    let client = makeClient(mock)
    for n in [99, 1001] {
        do {
            _ = try await client.designVoice(description: "d", previewText: String(repeating: "a", count: n))
            #expect(Bool(false))
        } catch let error as ElevenLabsError {
            guard case .invalidDesignText(let count) = error else { #expect(Bool(false)); return }
            #expect(count == n)
        } catch { #expect(Bool(false)) }
    }
    #expect(await mock.capturedRequests.isEmpty)
}

@Test func designAutoGenerateTextAndDefaultModel() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("{\"previews\":[],\"text\":\"t\"}".utf8))
    let client = makeClient(mock)
    _ = try await client.designVoice(description: "d", autoGenerateText: true)
    let body = bodyJSON(await mock.capturedRequests[0])
    #expect(body["auto_generate_text"] as? Bool == true)
    #expect(body["model_id"] as? String == "eleven_multilingual_ttv_v2")
    #expect(body["text"] == nil)
}
