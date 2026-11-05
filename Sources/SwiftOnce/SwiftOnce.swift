import Foundation

public actor SwiftOnce {
    public static let version = "1.1.0"

    private let apiKey: String
    private let configuration: SwiftOnceConfiguration
    private let httpClient: any HTTPClient
    private let voiceCache: VoiceCache
    private let audioCache: AudioCache
    private let decoder: JSONDecoder
    private var resolvedDefaultVoice: Voice?
    private let sleeper: @Sendable (TimeInterval) async throws -> Void

    // Concurrency gate for API rate limiting
    private var activeRequests = 0
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []

    public init(
        apiKey: String,
        configuration: SwiftOnceConfiguration = .init(),
        httpClient: (any HTTPClient)? = nil
    ) {
        self.init(apiKey: apiKey, configuration: configuration, httpClient: httpClient, sleeper: nil)
    }

    /// Internal designated init; `sleeper` lets tests observe and skip retry delays.
    init(
        apiKey: String,
        configuration: SwiftOnceConfiguration,
        httpClient: (any HTTPClient)?,
        sleeper: (@Sendable (TimeInterval) async throws -> Void)?
    ) {
        self.sleeper = sleeper ?? { try await Task.sleep(for: .seconds($0)) }
        self.apiKey = apiKey
        self.configuration = configuration
        self.httpClient = httpClient ?? URLSession.shared
        self.voiceCache = VoiceCache(ttl: configuration.voiceCacheTTL)
        self.audioCache = AudioCache(directory: configuration.audioCacheDirectory, maxBytes: configuration.audioCacheMaxBytes)
        self.decoder = JSONDecoder()
    }

    // MARK: - Default Voice

    public var defaultVoice: Voice? { resolvedDefaultVoice }

    /// Resolves the default voice.
    ///
    /// Resolution order:
    /// 1. Return cached voice if already resolved.
    /// 2. If `configuration.defaultVoiceId` is set, fetch by ID via
    ///    `GET /v1/voices/{id}` (faster than a search).
    /// 3. If ID lookup fails or is nil, fall back to name-based search
    ///    using `configuration.defaultVoiceName`.
    /// 4. Throw `.defaultVoiceNotFound` if both fail.
    @discardableResult
    public func resolveDefaultVoice() async throws -> Voice {
        if let cached = resolvedDefaultVoice {
            return cached
        }

        // Try ID-based lookup first (fast, direct GET)
        if let voiceId = configuration.defaultVoiceId {
            do {
                let match = try await voice(voiceId)
                resolvedDefaultVoice = match
                return match
            } catch {
                // ID lookup failed (404, network, etc.) — fall through to name search
            }
        }

        // Fall back to name-based search
        guard let name = configuration.defaultVoiceName else {
            throw ElevenLabsError.defaultVoiceNotFound(
                configuration.defaultVoiceId ?? "No default voice ID or name configured"
            )
        }
        let result = try await voices(search: name)
        let lowered = name.lowercased()
        guard let match = result.voices.first(where: { $0.name.lowercased() == lowered }) else {
            throw ElevenLabsError.defaultVoiceNotFound(name)
        }
        resolvedDefaultVoice = match
        return match
    }

    public func speak(
        _ text: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil
    ) async throws -> Data {
        let voice = try await resolveDefaultVoice()
        return try await speak(text, voice: voice.voiceId, model: model, outputFormat: outputFormat)
    }

    // MARK: - Text to Speech (Simple)

    public func speak(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil
    ) async throws -> Data {
        try await speak(
            text,
            voice: voiceId,
            model: model,
            outputFormat: outputFormat,
            languageCode: nil,
            voiceSettings: nil,
            seed: nil,
            previousText: nil,
            nextText: nil,
            previousRequestIds: nil,
            nextRequestIds: nil,
            pronunciationDictionaryLocators: nil,
            applyTextNormalization: nil,
            optimizeStreamingLatency: nil,
            enableLogging: nil
        )
    }

    // MARK: - Text to Speech (Full Parameters)

    public func speak(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil,
        languageCode: String? = nil,
        voiceSettings: VoiceSettings? = nil,
        seed: Int? = nil,
        previousText: String? = nil,
        nextText: String? = nil,
        previousRequestIds: [String]? = nil,
        nextRequestIds: [String]? = nil,
        pronunciationDictionaryLocators: [[String: String]]? = nil,
        applyTextNormalization: TextNormalization? = nil,
        optimizeStreamingLatency: StreamingLatencyOptimization? = nil,
        enableLogging: Bool? = nil
    ) async throws -> Data {
        try await speakResult(
            text, voice: voiceId, model: model, outputFormat: outputFormat,
            languageCode: languageCode, voiceSettings: voiceSettings, seed: seed,
            previousText: previousText, nextText: nextText,
            previousRequestIds: previousRequestIds, nextRequestIds: nextRequestIds,
            pronunciationDictionaryLocators: pronunciationDictionaryLocators,
            applyTextNormalization: applyTextNormalization,
            optimizeStreamingLatency: optimizeStreamingLatency, enableLogging: enableLogging
        ).audio
    }

    // MARK: - Text to Speech (with request id)

    /// Same as the full `speak`, but also returns the `request-id` response header
    /// so it can be passed as `previousRequestIds` / `nextRequestIds` on later calls.
    public func speakResult(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil,
        languageCode: String? = nil,
        voiceSettings: VoiceSettings? = nil,
        seed: Int? = nil,
        previousText: String? = nil,
        nextText: String? = nil,
        previousRequestIds: [String]? = nil,
        nextRequestIds: [String]? = nil,
        pronunciationDictionaryLocators: [[String: String]]? = nil,
        applyTextNormalization: TextNormalization? = nil,
        optimizeStreamingLatency: StreamingLatencyOptimization? = nil,
        enableLogging: Bool? = nil
    ) async throws -> SpeechResult {
        let resolvedModel = model ?? configuration.defaultModel
        try Self.checkTextLength(text, model: resolvedModel)
        let resolvedFormat = outputFormat ?? configuration.defaultOutputFormat

        // Check audio cache
        let cacheKey = AudioCache.cacheKey(
            text: text, voiceId: voiceId, model: resolvedModel,
            outputFormat: resolvedFormat, settings: voiceSettings
        )
        if let cached = try? await audioCache.get(key: cacheKey) {
            return SpeechResult(audio: cached, requestId: nil)
        }

        let body = buildTTSBody(
            text: text, model: resolvedModel, languageCode: languageCode,
            voiceSettings: voiceSettings, seed: seed, previousText: previousText,
            nextText: nextText, previousRequestIds: previousRequestIds,
            nextRequestIds: nextRequestIds,
            pronunciationDictionaryLocators: pronunciationDictionaryLocators,
            applyTextNormalization: applyTextNormalization
        )

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "output_format", value: resolvedFormat.rawValue)
        ]
        if let latency = optimizeStreamingLatency {
            queryItems.append(URLQueryItem(name: "optimize_streaming_latency", value: "\(latency.rawValue)"))
        }
        if let logging = enableLogging {
            queryItems.append(URLQueryItem(name: "enable_logging", value: "\(logging)"))
        }

        let request = Endpoint.textToSpeech(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, queryItems: queryItems, body: body, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        // Cache the result
        try? await audioCache.set(key: cacheKey, data: data)

        let requestId = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "request-id")
        return SpeechResult(audio: data, requestId: requestId)
    }

    // MARK: - Streaming

    public func stream(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil,
        voiceSettings: VoiceSettings? = nil,
        optimizeStreamingLatency: StreamingLatencyOptimization? = nil
    ) -> AsyncThrowingStream<Data, Error> {
        let resolvedModel = model ?? configuration.defaultModel
        if let error = Self.lengthError(text, model: resolvedModel) {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        let resolvedFormat = outputFormat ?? configuration.defaultOutputFormat

        let body = buildTTSBody(text: text, model: resolvedModel, voiceSettings: voiceSettings)

        var queryItems = [URLQueryItem(name: "output_format", value: resolvedFormat.rawValue)]
        if let latency = optimizeStreamingLatency {
            queryItems.append(URLQueryItem(name: "optimize_streaming_latency", value: "\(latency.rawValue)"))
        }

        let request = Endpoint.textToSpeechStream(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, queryItems: queryItems, body: body, userAgent: configuration.userAgent)

        let client = self.httpClient
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await client.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: ElevenLabsError.httpError(statusCode: statusCode, body: nil))
                        return
                    }

                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)
                        if buffer.count >= 4096 {
                            continuation.yield(buffer)
                            buffer = Data()
                        }
                    }
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ElevenLabsError.networkError(error))
                }
            }
        }
    }

    // MARK: - Timestamps

    public func speakWithTimestamps(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil,
        voiceSettings: VoiceSettings? = nil
    ) async throws -> TimestampedAudio {
        let resolvedModel = model ?? configuration.defaultModel
        try Self.checkTextLength(text, model: resolvedModel)
        let resolvedFormat = outputFormat ?? configuration.defaultOutputFormat

        let body = buildTTSBody(text: text, model: resolvedModel, voiceSettings: voiceSettings)
        let queryItems = [URLQueryItem(name: "output_format", value: resolvedFormat.rawValue)]

        let request = Endpoint.textToSpeechWithTimestamps(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, queryItems: queryItems, body: body, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let dto = try decoder.decode(TimestampedResponseDTO.self, from: data)
        let audioData: Data
        if let base64 = dto.audioBase64 {
            guard let decoded = Data(base64Encoded: base64) else {
                throw ElevenLabsError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid base64 audio data")))
            }
            audioData = decoded
        } else {
            audioData = Data()
        }

        return TimestampedAudio(
            audioData: audioData,
            alignment: dto.alignment,
            normalizedAlignment: dto.normalizedAlignment
        )
    }

    public func streamWithTimestamps(
        _ text: String,
        voice voiceId: String,
        model: Model? = nil,
        outputFormat: OutputFormat? = nil,
        voiceSettings: VoiceSettings? = nil
    ) -> AsyncThrowingStream<TimestampedChunk, Error> {
        let resolvedModel = model ?? configuration.defaultModel
        if let error = Self.lengthError(text, model: resolvedModel) {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        let resolvedFormat = outputFormat ?? configuration.defaultOutputFormat

        let body = buildTTSBody(text: text, model: resolvedModel, voiceSettings: voiceSettings)
        let queryItems = [URLQueryItem(name: "output_format", value: resolvedFormat.rawValue)]

        let request = Endpoint.textToSpeechStreamWithTimestamps(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, queryItems: queryItems, body: body, userAgent: configuration.userAgent)

        let client = self.httpClient
        let localDecoder = self.decoder
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let (bytes, response) = try await client.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: ElevenLabsError.httpError(statusCode: statusCode, body: nil))
                        return
                    }

                    var lineBuffer = Data()
                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            if !lineBuffer.isEmpty {
                                if let dto = try? localDecoder.decode(TimestampedResponseDTO.self, from: lineBuffer) {
                                    let audioData = dto.audioBase64.flatMap { Data(base64Encoded: $0) }
                                    continuation.yield(TimestampedChunk(
                                        audioData: audioData,
                                        alignment: dto.alignment,
                                        normalizedAlignment: dto.normalizedAlignment
                                    ))
                                }
                                lineBuffer = Data()
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: ElevenLabsError.networkError(error))
                }
            }
        }
    }

    // MARK: - Voices

    public func voices(
        search: String? = nil,
        category: VoiceCategory? = nil,
        collectionId: String? = nil,
        voiceType: VoiceType? = nil,
        sort: VoiceSortField? = nil,
        sortDirection: SortDirection? = nil,
        pageSize: Int? = nil,
        pageToken: String? = nil
    ) async throws -> VoiceListResponse {
        var queryItems: [URLQueryItem] = []
        if let search { queryItems.append(.init(name: "search", value: search)) }
        if let category { queryItems.append(.init(name: "category", value: category.rawValue)) }
        if let collectionId { queryItems.append(.init(name: "collection_id", value: collectionId)) }
        if let voiceType { queryItems.append(.init(name: "voice_type", value: voiceType.rawValue)) }
        if let sort { queryItems.append(.init(name: "sort", value: sort.rawValue)) }
        if let sortDirection { queryItems.append(.init(name: "sort_direction", value: sortDirection.rawValue)) }
        if let pageSize { queryItems.append(.init(name: "page_size", value: "\(pageSize)")) }
        if let pageToken { queryItems.append(.init(name: "next_page_token", value: pageToken)) }

        let cacheKey = queryItems.map { "\($0.name)=\($0.value ?? "")" }.sorted().joined(separator: "&")

        if let cached = await voiceCache.get(key: cacheKey) {
            return cached
        }

        let request = Endpoint.voices
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, queryItems: queryItems, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        let voiceList = try decoder.decode(VoiceListResponse.self, from: data)
        await voiceCache.set(key: cacheKey, value: voiceList)

        return voiceList
    }

    public func voice(_ voiceId: String) async throws -> Voice {
        if let cached = await voiceCache.getVoice(voiceId) {
            return cached
        }

        let request = Endpoint.voice(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        return try decoder.decode(Voice.self, from: data)
    }

    /// `DELETE /v1/voices/{id}`. Invalidates the voice cache (and the resolved
    /// default voice if it was the deleted one) on success.
    public func deleteVoice(_ voiceId: String) async throws {
        let request = Endpoint.deleteVoice(voiceId: voiceId)
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)

        await voiceCache.invalidate()
        if resolvedDefaultVoice?.voiceId == voiceId { resolvedDefaultVoice = nil }
    }

    // MARK: - Models & Subscription

    /// `GET /v1/models`.
    public func models() async throws -> [ModelInfo] {
        let request = Endpoint.models
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, userAgent: configuration.userAgent)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode([ModelInfo].self, from: data)
        } catch {
            throw ElevenLabsError.decodingError(error)
        }
    }

    /// `GET /v1/user/subscription`.
    public func subscription() async throws -> Subscription {
        let request = Endpoint.subscription
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, userAgent: configuration.userAgent)
        let (data, response) = try await performRequest(request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(Subscription.self, from: data)
        } catch {
            throw ElevenLabsError.decodingError(error)
        }
    }

    public func invalidateVoiceCache() async {
        await voiceCache.invalidate()
        resolvedDefaultVoice = nil
    }

    // MARK: - Audio Cache Management

    public func clearAudioCache() async throws {
        try await audioCache.clear()
    }

    public func audioCacheSize() async throws -> Int64 {
        try await audioCache.totalSize()
    }

    // MARK: - Voice Design

    public func designVoice(
        description: String,
        previewText: String? = nil
    ) async throws -> VoiceDesignResponse {
        try await designVoice(
            description: description,
            previewText: previewText,
            model: nil,
            loudness: nil,
            guidanceScale: nil,
            seed: nil,
            autoGenerateText: nil
        )
    }

    public func designVoice(
        description: String,
        previewText: String? = nil,
        model: VoiceDesignModel? = nil,
        loudness: Double? = nil,
        guidanceScale: Double? = nil,
        seed: Int? = nil,
        autoGenerateText: Bool? = nil
    ) async throws -> VoiceDesignResponse {
        if let previewText, !(100...1000).contains(previewText.count) {
            throw ElevenLabsError.invalidDesignText(count: previewText.count)
        }
        var dict: [String: Any] = [
            "voice_description": description,
        ]
        if let previewText { dict["text"] = previewText }
        if let autoGenerateText { dict["auto_generate_text"] = autoGenerateText }
        dict["model_id"] = (model ?? configuration.defaultDesignModel).rawValue
        if let loudness { dict["loudness"] = loudness }
        if let guidanceScale { dict["guidance_scale"] = guidanceScale }
        if let seed { dict["seed"] = seed }

        let body = try! JSONSerialization.data(withJSONObject: dict)
        let request = Endpoint.voiceDesign
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, body: body, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request, retryConflict: true)
        try validateResponse(response, data: data)

        let dto = try decoder.decode(VoiceDesignResponseDTO.self, from: data)
        let previews = try dto.previews.map { preview in
            guard let audioData = Data(base64Encoded: preview.audioBase64) else {
                throw ElevenLabsError.decodingError(DecodingError.dataCorrupted(
                    .init(codingPath: [], debugDescription: "Invalid base64 audio data in voice preview")))
            }
            return VoicePreview(
                id: preview.generatedVoiceId,
                audioData: audioData,
                mediaType: preview.mediaType,
                duration: preview.durationSecs,
                language: preview.language
            )
        }
        return VoiceDesignResponse(previews: previews, text: dto.text)
    }

    public func createVoice(
        from preview: VoicePreview,
        name: String,
        description: String,
        labels: [String: String]? = nil
    ) async throws -> Voice {
        var dict: [String: Any] = [
            "generated_voice_id": preview.id,
            "voice_name": name,
            "voice_description": description,
        ]
        if let labels { dict["labels"] = labels }

        let body = try! JSONSerialization.data(withJSONObject: dict)
        let request = Endpoint.createVoice
            .urlRequest(baseURL: configuration.baseURL, apiKey: apiKey, body: body, userAgent: configuration.userAgent)

        let (data, response) = try await performRequest(request, retryConflict: true)
        try validateResponse(response, data: data)

        return try decoder.decode(Voice.self, from: data)
    }

    // MARK: - Concurrency Gate

    private func acquireSlot() async {
        if activeRequests < configuration.maxConcurrentRequests {
            activeRequests += 1
            return
        }
        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }

    private func releaseSlot() {
        if let next = waitingContinuations.first {
            waitingContinuations.removeFirst()
            next.resume()
        } else {
            activeRequests -= 1
        }
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest, retryConflict: Bool = false) async throws -> (Data, URLResponse) {
        await acquireSlot()
        defer { releaseSlot() }

        var attempt = 0
        while true {
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await httpClient.data(for: request)
            } catch let error as ElevenLabsError {
                throw error
            } catch {
                throw ElevenLabsError.networkError(error)
            }

            guard let http = response as? HTTPURLResponse else { return (data, response) }
            let status = http.statusCode
            let retryable = status == 429 || (500...599).contains(status) || (retryConflict && status == 409)
            guard retryable else { return (data, response) }

            let retryAfter = Self.parseRetryAfter(http.value(forHTTPHeaderField: "Retry-After"))
            if attempt >= configuration.maxRetries {
                if status == 429 {
                    throw ElevenLabsError.rateLimited(retryAfterSeconds: retryAfter.map { Int($0.rounded(.up)) })
                }
                return (data, response)  // validateResponse maps it to .httpError
            }
            try await sleeper(Self.retryDelay(attempt: attempt, retryAfter: retryAfter))
            attempt += 1
        }
    }

    // MARK: - Retry / error helpers

    /// Parses `Retry-After` as integer seconds or an HTTP-date. Returns seconds from `now`.
    static func parseRetryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = Int(value) { return TimeInterval(max(0, seconds)) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEEE, dd-MMM-yy HH:mm:ss zzz", "EEE MMM d HH:mm:ss yyyy"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return max(0, date.timeIntervalSince(now))
            }
        }
        return nil
    }

    /// Retry-After wins when present; otherwise jittered exponential backoff capped at 30 s.
    static func retryDelay(attempt: Int, retryAfter: TimeInterval?) -> TimeInterval {
        if let retryAfter { return retryAfter }
        let base = Double(min(1 << min(attempt, 5), 30))
        return base * Double.random(in: 0.5...1.0)
    }

    static func lengthError(_ text: String, model: Model) -> ElevenLabsError? {
        guard let limit = model.maxTextLength, text.count > limit else { return nil }
        return .textTooLong(model: model.rawValue, limit: limit, count: text.count)
    }

    static func checkTextLength(_ text: String, model: Model) throws {
        if let error = lengthError(text, model: model) { throw error }
    }

    /// `detail.status` and `detail.message` from an ElevenLabs error body, if present.
    private static func errorDetail(_ data: Data) -> (status: String?, message: String?) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let detail = object["detail"] as? [String: Any] else { return (nil, nil) }
        return (detail["status"] as? String, detail["message"] as? String)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        let statusCode = httpResponse.statusCode
        if (200...299).contains(statusCode) { return }

        let detail = Self.errorDetail(data)
        switch detail.status {
        case "quota_exceeded":
            throw ElevenLabsError.quotaExceeded
        case "voice_limit_reached", "voice_limit_exceeded", "max_voice_limit_reached":
            throw ElevenLabsError.voiceLimitReached(detail.message)
        default:
            break
        }

        switch statusCode {
        case 401:
            throw ElevenLabsError.invalidAPIKey
        case 404:
            throw ElevenLabsError.voiceNotFound(String(data: data, encoding: .utf8) ?? "")
        case 422:
            throw ElevenLabsError.invalidRequest(String(data: data, encoding: .utf8) ?? "")
        case 429:
            let retryAfter = Self.parseRetryAfter(httpResponse.value(forHTTPHeaderField: "Retry-After"))
            throw ElevenLabsError.rateLimited(retryAfterSeconds: retryAfter.map { Int($0.rounded(.up)) })
        default:
            throw ElevenLabsError.httpError(statusCode: statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    private func buildTTSBody(
        text: String,
        model: Model,
        languageCode: String? = nil,
        voiceSettings: VoiceSettings? = nil,
        seed: Int? = nil,
        previousText: String? = nil,
        nextText: String? = nil,
        previousRequestIds: [String]? = nil,
        nextRequestIds: [String]? = nil,
        pronunciationDictionaryLocators: [[String: String]]? = nil,
        applyTextNormalization: TextNormalization? = nil
    ) -> Data {
        var dict: [String: Any] = [
            "text": text,
            "model_id": model.rawValue,
        ]

        if let languageCode { dict["language_code"] = languageCode }
        if let voiceSettings { dict["voice_settings"] = voiceSettings.apiDictionary }
        if let seed { dict["seed"] = seed }
        if let previousText { dict["previous_text"] = previousText }
        if let nextText { dict["next_text"] = nextText }
        if let previousRequestIds { dict["previous_request_ids"] = previousRequestIds }
        if let nextRequestIds { dict["next_request_ids"] = nextRequestIds }
        if let pronunciationDictionaryLocators { dict["pronunciation_dictionary_locators"] = pronunciationDictionaryLocators }
        if let applyTextNormalization { dict["apply_text_normalization"] = applyTextNormalization.rawValue }

        return try! JSONSerialization.data(withJSONObject: dict)
    }
}
