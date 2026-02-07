# SwiftOnce Agent Instructions

## Project Overview

SwiftOnce (pronounced "UN-say", from Spanish for eleven) is a Swift 6.2 library wrapping the ElevenLabs TTS REST API. It provides text-to-speech generation, voice discovery, and audio file caching with zero external dependencies.

## Build & Test

- **Build:** `xcodebuild build -scheme SwiftOnce -destination 'platform=macOS'`
- **Test:** `xcodebuild test -scheme SwiftOnce -destination 'platform=macOS'`
- Do NOT use `swift build` or `swift test` — always use `xcodebuild`.
- Swift tools version is 6.2. All code must compile under Swift 6 strict concurrency.

## Architecture

- **Main client:** `SwiftOnce` is an `actor` — all public API is async.
- **Networking:** `HTTPClient` protocol with `URLSession` conformance. Injectable for testing.
- **Caching:** Two actor-based caches — `VoiceCache` (in-memory, TTL) and `AudioCache` (file-system, LRU with SHA256 keys via CryptoKit).
- **Models:** All public types are `Sendable`, `Codable`, and use explicit `CodingKeys` for snake_case JSON mapping.
- **Errors:** Single `ElevenLabsError` enum covers all failure modes.

## Code Conventions

- No UI framework imports (no SwiftUI, UIKit, AppKit). This is a pure Swift library.
- Platforms: macOS 26+, iOS 26+.
- Zero external dependencies. Only Foundation and CryptoKit.
- Use `MARK:` comments to organize methods into logical sections.
- Async/await throughout. No Combine, no completion handlers.
- Enums use `camelCase` cases with `rawValue` strings matching the ElevenLabs API.
- Functions use labeled parameters matching the API domain language (e.g., `voice:` not `voiceId:`).
- Provide simple convenience overloads alongside full-parameter methods.

## Testing

- Use Swift Testing framework (`import Testing`, `@Test` macro). Not XCTest.
- Mock networking via `MockHTTPClient` (enqueue responses, capture requests).
- Test files live in `Tests/SwiftOnceTests/`, mocks in `Tests/SwiftOnceTests/Mocks/`.
- All tests must pass before committing.

## File Layout

```
Sources/SwiftOnce/
├── SwiftOnce.swift              # Main actor client
├── Configuration.swift          # SwiftOnceConfiguration
├── ElevenLabsDefaults.swift     # Canonical constants (voice ID, scheme, URI helpers)
├── Errors.swift                 # ElevenLabsError
├── Models/
│   ├── Enums.swift              # Model, OutputFormat, VoiceCategory, etc.
│   ├── Voice.swift              # Voice, VerifiedLanguage, VoiceListResponse
│   ├── VoiceSettings.swift      # VoiceSettings
│   ├── VoiceDesign.swift         # VoicePreview, VoiceDesignResponse, DTOs
│   └── TimestampedResponse.swift
├── Networking/
│   ├── HTTPClient.swift         # Protocol + URLSession conformance
│   └── Endpoint.swift           # API route enum
└── Cache/
    ├── VoiceCache.swift         # In-memory TTL cache
    └── AudioCache.swift         # File-system LRU cache
```

## Default Voice

SwiftOnce provides canonical constants and a resolution mechanism for the ElevenLabs default voice.

### ElevenLabsDefaults (single source of truth)

The `ElevenLabsDefaults` enum in `Sources/SwiftOnce/ElevenLabsDefaults.swift` holds:
- `defaultVoiceId` — the canonical default ElevenLabs voice ID (`Gsndh0O5AnuI2Hj3YUlA`)
- `providerScheme` — the URI scheme string (`elevenlabs`)
- `voiceURI(voiceId:languageCode:)` — builds a full voice URI
- `defaultVoiceURI(languageCode:)` — builds a URI for the default voice

Downstream packages (SwiftHablare, SwiftEchada) must reference these constants instead of duplicating the strings.

### Configuration

`SwiftOnceConfiguration` has two default-voice properties:
- `defaultVoiceId: String?` — defaults to `ElevenLabsDefaults.defaultVoiceId`
- `defaultVoiceName: String?` — defaults to `"narrator"` (fallback for name-based search)

### Resolution

`SwiftOnce.resolveDefaultVoice()` uses this order:
1. Return cached voice if already resolved.
2. If `defaultVoiceId` is set, fetch via `GET /v1/voices/{id}` (fast, direct).
3. If ID lookup fails (404, etc.), fall back to name-based search using `defaultVoiceName`.
4. Throw `ElevenLabsError.defaultVoiceNotFound` if both fail.

## ElevenLabs API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/text-to-speech/{voice_id}` | Generate audio |
| POST | `/v1/text-to-speech/{voice_id}/stream` | Stream audio |
| POST | `/v1/text-to-speech/{voice_id}/with-timestamps` | Audio + timestamps |
| POST | `/v1/text-to-speech/{voice_id}/stream/with-timestamps` | Stream + timestamps |
| GET | `/v2/voices` | List/search/filter voices |
| GET | `/v1/voices/{voice_id}` | Get single voice |
| POST | `/v1/text-to-voice/design` | Design voice from description |
| POST | `/v1/text-to-voice` | Save designed voice permanently |

## Security

- Never echo, print, or log API keys.
- The library accepts API keys as constructor parameters — no Keychain dependency.
- When verifying env vars exist, use existence checks only.

## Versioning

- Version numbers must be bumped manually in `Package.swift` before each release.
- There is no automated version bump workflow.
- Git tags are the ultimate source of truth for determining the next published version.

## GitHub Actions CI/CD

- Always use `macos-26` or later for runners.
- Swift version must be 6.2 or later.
- iOS simulator destination: `'platform=iOS Simulator,name=iPhone 17,OS=26.1'`
- Never use `OS=latest` — always specify an exact OS version.
