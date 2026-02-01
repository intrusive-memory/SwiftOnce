# SwiftOnce

A Swift 6.2 library wrapping the [ElevenLabs](https://elevenlabs.io) TTS REST API. Provides text-to-speech generation, voice discovery, voice design, streaming, and audio file caching with zero external dependencies.

The name is pronounced "UN-say", from the Spanish word for eleven.

## Requirements

- Swift 6.2+
- macOS 26+ / iOS 26+
- Xcode 17+

## Installation

Add SwiftOnce as a Swift Package Manager dependency:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftOnce.git", from: "0.1.0"),
],
targets: [
    .target(name: "MyApp", dependencies: ["SwiftOnce"]),
]
```

## Quick Start

```swift
import SwiftOnce

let client = SwiftOnce(apiKey: "your-elevenlabs-api-key")

// Generate speech
let audioData = try await client.speak("Hello, world!", voice: "JBFqnCBsd6RMkjVDRZzb")

// List voices
let voiceList = try await client.voices()
for voice in voiceList.voices {
    print("\(voice.name) — \(voice.id)")
}
```

## API Reference

### Initialization

```swift
let client = SwiftOnce(
    apiKey: "your-api-key",
    configuration: SwiftOnceConfiguration(
        defaultModel: .multilingualV2,       // default TTS model
        defaultOutputFormat: .mp3_44100_128,  // default audio format
        voiceCacheTTL: 300,                   // voice cache lifetime in seconds
        audioCacheMaxBytes: 500_000_000       // max disk cache size (500 MB)
    )
)
```

### Text to Speech

```swift
// Simple
let audio = try await client.speak("Hello", voice: "voiceId")

// Full parameters
let audio = try await client.speak(
    "Hello",
    voice: "voiceId",
    model: .v3,
    outputFormat: .mp3_44100_192,
    languageCode: "en",
    voiceSettings: VoiceSettings(stability: 0.7, similarityBoost: 0.8, style: 0.5, speed: 1.0),
    seed: 42,
    previousText: "Previously...",
    nextText: "And then...",
    applyTextNormalization: .auto,
    optimizeStreamingLatency: .level2,
    enableLogging: true
)
```

### Streaming

```swift
let stream = client.stream("Long text here...", voice: "voiceId", model: .v3)

for try await chunk in stream {
    // Process audio chunks as they arrive
    audioPlayer.enqueue(chunk)
}
```

### Timestamps

Get word-level timing aligned with audio:

```swift
let result = try await client.speakWithTimestamps("Hello world", voice: "voiceId")
// result.audioData — the audio bytes
// result.alignment — character/word timing data

// Streaming with timestamps
let stream = client.streamWithTimestamps("Hello world", voice: "voiceId")
for try await chunk in stream {
    // chunk.audioData, chunk.alignment
}
```

### Voices

```swift
// List all voices
let list = try await client.voices()

// Search and filter
let filtered = try await client.voices(
    search: "Rachel",
    category: .premade,
    voiceType: .default,
    sort: .createdAt,
    sortDirection: .descending,
    pageSize: 20
)

// Get a single voice by ID
let voice = try await client.voice("JBFqnCBsd6RMkjVDRZzb")
```

### Voice Design

Generate new voices from a text description, then save them:

```swift
// Design a voice — returns up to 3 previews
let response = try await client.designVoice(
    description: "Deep, warm baritone with measured pacing and gravitas, middle-aged, calm authority",
    previewText: "To be, or not to be, that is the question."
)

// Listen to previews and pick one
let selectedPreview = response.previews[0]
print("Preview ID: \(selectedPreview.id)")
print("Duration: \(selectedPreview.duration)s")
// selectedPreview.audioData contains the decoded audio bytes

// Save the selected preview as a permanent voice
let voice = try await client.createVoice(
    from: selectedPreview,
    name: "Narrator",
    description: "Deep baritone narrator voice",
    labels: ["gender": "male", "use_case": "narration"]
)

print("Permanent voice ID: \(voice.id)")
```

Full design parameters:

```swift
let response = try await client.designVoice(
    description: "Young female with bright, energetic tone",
    previewText: "Welcome to the show!",
    model: .v3,            // .v2 or .v3
    loudness: 0.5,
    guidanceScale: 3.0,
    seed: 12345
)
```

### Cache Management

SwiftOnce caches voice metadata in memory (TTL-based) and audio on disk (LRU):

```swift
// Invalidate the in-memory voice cache
await client.invalidateVoiceCache()

// Clear the on-disk audio cache
try await client.clearAudioCache()

// Check audio cache size in bytes
let bytes = try await client.audioCacheSize()
```

## Models

| Enum Case | API Value | Notes |
|-----------|-----------|-------|
| `.v3` | `eleven_v3` | Latest |
| `.multilingualV2` | `eleven_multilingual_v2` | Default |
| `.flashV2_5` | `eleven_flash_v2_5` | Low latency |
| `.turboV2_5` | `eleven_turbo_v2_5` | Low latency |
| `.turboV2` | `eleven_turbo_v2` | Legacy |
| `.flashV2` | `eleven_flash_v2` | Legacy |
| `.multilingualV1` | `eleven_multilingual_v1` | Legacy |
| `.monolingualV1` | `eleven_monolingual_v1` | Legacy |

## Output Formats

MP3, PCM, Opus, WAV, mu-law, and A-law are supported at various sample rates and bitrates. See the `OutputFormat` enum for all options. Default is `mp3_44100_128`.

## Error Handling

All errors are thrown as `ElevenLabsError`:

```swift
do {
    let audio = try await client.speak("Hello", voice: "voiceId")
} catch let error as ElevenLabsError {
    switch error {
    case .invalidAPIKey:
        print("Check your API key")
    case .rateLimited(let retryAfter):
        print("Rate limited, retry after \(retryAfter ?? 0)s")
    case .voiceNotFound(let detail):
        print("Voice not found: \(detail)")
    case .invalidRequest(let detail):
        print("Invalid request: \(detail)")
    case .httpError(let statusCode, let body):
        print("HTTP \(statusCode): \(body ?? "")")
    case .networkError(let underlying):
        print("Network error: \(underlying)")
    case .decodingError(let underlying):
        print("Decoding error: \(underlying)")
    case .quotaExceeded:
        print("Quota exceeded")
    case .cachingError(let underlying):
        print("Cache error: \(underlying)")
    }
}
```

## Architecture

- `SwiftOnce` is an `actor` — all public API is `async` and concurrency-safe
- Zero external dependencies (Foundation + CryptoKit only)
- All public types conform to `Sendable`
- Injectable `HTTPClient` protocol for testing

## License

See [LICENSE](LICENSE) for details.
