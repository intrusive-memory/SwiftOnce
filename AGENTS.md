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
- Platforms: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+, visionOS 1+.
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
├── Errors.swift                 # ElevenLabsError
├── Models/
│   ├── Enums.swift              # Model, OutputFormat, VoiceCategory, etc.
│   ├── Voice.swift              # Voice, VerifiedLanguage, VoiceListResponse
│   ├── VoiceSettings.swift      # VoiceSettings
│   └── TimestampedResponse.swift
├── Networking/
│   ├── HTTPClient.swift         # Protocol + URLSession conformance
│   └── Endpoint.swift           # API route enum
└── Cache/
    ├── VoiceCache.swift         # In-memory TTL cache
    └── AudioCache.swift         # File-system LRU cache
```

## ElevenLabs API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/v1/text-to-speech/{voice_id}` | Generate audio |
| POST | `/v1/text-to-speech/{voice_id}/stream` | Stream audio |
| POST | `/v1/text-to-speech/{voice_id}/with-timestamps` | Audio + timestamps |
| POST | `/v1/text-to-speech/{voice_id}/stream/with-timestamps` | Stream + timestamps |
| GET | `/v2/voices` | List/search/filter voices |
| GET | `/v1/voices/{voice_id}` | Get single voice |

## Security

- Never echo, print, or log API keys.
- The library accepts API keys as constructor parameters — no Keychain dependency.
- When verifying env vars exist, use existence checks only.

## Versioning

- Version numbers must be bumped manually in `Package.swift` before each release.
- There is no automated version bump workflow.

## GitHub Actions CI/CD

- Always use `macos-26` or later for runners.
- Swift version must be 6.2 or later.
- iOS simulator destination: `'platform=iOS Simulator,name=iPhone 17,OS=26.1'`
- Never use `OS=latest` — always specify an exact OS version.
