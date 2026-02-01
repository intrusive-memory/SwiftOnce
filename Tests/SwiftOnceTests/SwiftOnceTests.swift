import Testing
import Foundation
@testable import SwiftOnce

// MARK: - Helper

private func testConfiguration() -> SwiftOnceConfiguration {
    SwiftOnceConfiguration(
        audioCacheDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    )
}

// MARK: - Endpoint Tests

@Test func testEndpointPaths() {
    #expect(Endpoint.textToSpeech(voiceId: "abc").path == "/v1/text-to-speech/abc")
    #expect(Endpoint.textToSpeechStream(voiceId: "abc").path == "/v1/text-to-speech/abc/stream")
    #expect(Endpoint.textToSpeechWithTimestamps(voiceId: "abc").path == "/v1/text-to-speech/abc/with-timestamps")
    #expect(Endpoint.textToSpeechStreamWithTimestamps(voiceId: "abc").path == "/v1/text-to-speech/abc/stream/with-timestamps")
    #expect(Endpoint.voices.path == "/v2/voices")
    #expect(Endpoint.voice(voiceId: "abc").path == "/v1/voices/abc")
}

@Test func testEndpointMethods() {
    #expect(Endpoint.textToSpeech(voiceId: "x").method == "POST")
    #expect(Endpoint.voices.method == "GET")
    #expect(Endpoint.voice(voiceId: "x").method == "GET")
}

@Test func testEndpointURLRequest() {
    let request = Endpoint.textToSpeech(voiceId: "v1")
        .urlRequest(
            baseURL: URL(string: "https://api.elevenlabs.io")!,
            apiKey: "test-key",
            queryItems: [URLQueryItem(name: "output_format", value: "mp3_44100_128")],
            body: Data("{}".utf8),
            userAgent: "TestAgent/1.0"
        )

    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "xi-api-key") == "test-key")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    #expect(request.value(forHTTPHeaderField: "User-Agent") == "TestAgent/1.0")
    #expect(request.url?.absoluteString.contains("output_format=mp3_44100_128") == true)
}

// MARK: - Model Tests

@Test func testModelRawValues() {
    #expect(Model.v3.rawValue == "eleven_v3")
    #expect(Model.multilingualV2.rawValue == "eleven_multilingual_v2")
    #expect(Model.flashV2_5.rawValue == "eleven_flash_v2_5")
    #expect(Model.turboV2_5.rawValue == "eleven_turbo_v2_5")
}

@Test func testOutputFormatMimeTypes() {
    #expect(OutputFormat.mp3_44100_128.mimeType == "audio/mpeg")
    #expect(OutputFormat.pcm_44100.mimeType == "audio/pcm")
    #expect(OutputFormat.wav_44100.mimeType == "audio/wav")
    #expect(OutputFormat.opus_48000_128.mimeType == "audio/opus")
}

@Test func testOutputFormatFileExtensions() {
    #expect(OutputFormat.mp3_44100_128.fileExtension == "mp3")
    #expect(OutputFormat.pcm_16000.fileExtension == "pcm")
    #expect(OutputFormat.wav_44100.fileExtension == "wav")
}

// MARK: - VoiceSettings Tests

@Test func testVoiceSettingsDefaults() {
    let settings = VoiceSettings()
    #expect(settings.stability == 0.5)
    #expect(settings.similarityBoost == 0.75)
    #expect(settings.style == nil)
    #expect(settings.speed == nil)
    #expect(settings.useSpeakerBoost == nil)
}

@Test func testVoiceSettingsCodable() throws {
    let settings = VoiceSettings(stability: 0.8, similarityBoost: 0.9, style: 0.3, speed: 1.2, useSpeakerBoost: true)
    let encoder = JSONEncoder()
    let data = try encoder.encode(settings)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(VoiceSettings.self, from: data)
    #expect(decoded.stability == 0.8)
    #expect(decoded.similarityBoost == 0.9)
    #expect(decoded.style == 0.3)
    #expect(decoded.speed == 1.2)
    #expect(decoded.useSpeakerBoost == true)
}

// MARK: - Voice Tests

@Test func testVoiceDecoding() throws {
    let json = """
    {
        "voice_id": "v123",
        "name": "Rachel",
        "category": "premade",
        "description": "A warm voice",
        "labels": {"accent": "american", "gender": "female"},
        "preview_url": "https://example.com/preview.mp3",
        "collection_ids": ["col1", "col2"],
        "high_quality_base_model_ids": ["eleven_multilingual_v2"],
        "is_owner": false,
        "is_legacy": false,
        "created_at_unix": 1700000000
    }
    """
    let voice = try JSONDecoder().decode(Voice.self, from: Data(json.utf8))
    #expect(voice.id == "v123")
    #expect(voice.name == "Rachel")
    #expect(voice.category == .premade)
    #expect(voice.labels["accent"] == "american")
    #expect(voice.collectionIds == ["col1", "col2"])
    #expect(voice.highQualityBaseModelIds == ["eleven_multilingual_v2"])
}

@Test func testVoiceDecodingMissingOptionalFields() throws {
    let json = """
    {"voice_id": "v1", "name": "Test"}
    """
    let voice = try JSONDecoder().decode(Voice.self, from: Data(json.utf8))
    #expect(voice.id == "v1")
    #expect(voice.name == "Test")
    #expect(voice.category == nil)
    #expect(voice.labels.isEmpty)
    #expect(voice.collectionIds.isEmpty)
}

@Test func testVoiceListResponseDecoding() throws {
    let json = """
    {
        "voices": [{"voice_id": "v1", "name": "Test"}],
        "has_more": true,
        "total_count": 50,
        "next_page_token": "abc123"
    }
    """
    let response = try JSONDecoder().decode(VoiceListResponse.self, from: Data(json.utf8))
    #expect(response.voices.count == 1)
    #expect(response.hasMore == true)
    #expect(response.totalCount == 50)
    #expect(response.nextPageToken == "abc123")
}

// MARK: - Configuration Tests

@Test func testConfigurationDefaults() {
    let config = SwiftOnceConfiguration()
    #expect(config.baseURL.absoluteString == "https://api.elevenlabs.io")
    #expect(config.userAgent == nil)
    #expect(config.voiceCacheTTL == 300)
    #expect(config.audioCacheMaxBytes == 500_000_000)
    #expect(config.defaultModel == .multilingualV2)
    #expect(config.defaultOutputFormat == .mp3_44100_128)
}

// MARK: - Client Integration Tests

@Test func testSpeakRequestConstruction() async throws {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("fake-audio".utf8), statusCode: 200)

    let client = SwiftOnce(apiKey: "test-key", configuration: testConfiguration(), httpClient: mock)
    let _ = try await client.speak("Hello", voice: "v1")

    let requests = await mock.capturedRequests
    #expect(requests.count == 1)
    let request = requests[0]
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "xi-api-key") == "test-key")
    #expect(request.url?.path.contains("/v1/text-to-speech/v1") == true)
}

@Test func testSpeakReturnsAudioData() async throws {
    let mock = MockHTTPClient()
    let audioBytes = Data("audio-content".utf8)
    await mock.enqueue(data: audioBytes, statusCode: 200)

    let client = SwiftOnce(apiKey: "key", configuration: testConfiguration(), httpClient: mock)
    let result = try await client.speak("Hi", voice: "v1")
    #expect(result == audioBytes)
}

@Test func testInvalidAPIKeyThrows() async {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("unauthorized".utf8), statusCode: 401)

    let client = SwiftOnce(apiKey: "bad-key", configuration: testConfiguration(), httpClient: mock)
    do {
        _ = try await client.speak("Hi", voice: "v1")
        #expect(Bool(false), "Should have thrown")
    } catch let error as ElevenLabsError {
        if case .invalidAPIKey = error {
            // expected
        } else {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
    }
}

@Test func testRateLimitThrows() async {
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data("rate limited".utf8), statusCode: 429)

    let client = SwiftOnce(apiKey: "key", configuration: testConfiguration(), httpClient: mock)
    do {
        _ = try await client.speak("Hi", voice: "v1")
        #expect(Bool(false), "Should have thrown")
    } catch let error as ElevenLabsError {
        if case .rateLimited = error {
            // expected
        } else {
            #expect(Bool(false), "Wrong error type: \(error)")
        }
    } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
    }
}

@Test func testVoicesRequestConstruction() async throws {
    let json = """
    {"voices": [], "has_more": false}
    """
    let mock = MockHTTPClient()
    await mock.enqueue(data: Data(json.utf8), statusCode: 200)

    let client = SwiftOnce(apiKey: "key", configuration: testConfiguration(), httpClient: mock)
    let _ = try await client.voices(search: "Rachel", category: .premade, pageSize: 10)

    let requests = await mock.capturedRequests
    let request = requests[0]
    #expect(request.httpMethod == "GET")
    let url = request.url?.absoluteString ?? ""
    #expect(url.contains("search=Rachel"))
    #expect(url.contains("category=premade"))
    #expect(url.contains("page_size=10"))
}

// MARK: - Cache Tests

@Test func testAudioCacheKey() {
    let key1 = AudioCache.cacheKey(text: "hello", voiceId: "v1", model: .multilingualV2, outputFormat: .mp3_44100_128, settings: nil)
    let key2 = AudioCache.cacheKey(text: "hello", voiceId: "v1", model: .multilingualV2, outputFormat: .mp3_44100_128, settings: nil)
    let key3 = AudioCache.cacheKey(text: "world", voiceId: "v1", model: .multilingualV2, outputFormat: .mp3_44100_128, settings: nil)

    #expect(key1 == key2)
    #expect(key1 != key3)
    #expect(key1.count == 64) // SHA256 hex
}
