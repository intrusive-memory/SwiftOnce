# Changelog

## 1.1.1

### Added
- `createVoice(generatedVoiceId:name:description:labels:)` creates a permanent voice from a
  `generated_voice_id` obtained in an earlier process. `createVoice(from:)` now delegates to it.
- Public memberwise initializer on `VoicePreview`.
- Optional `outputFormat` on `designVoice` (sent as the `output_format` query item, e.g. `pcm_24000`).
  Omitted by default, so existing behavior is unchanged.

## 1.1.0

Closes the ElevenLabs API audit gaps (commit d8a5068).

### Added
- v4 model support (`eleven_v4`).
- Models and subscription endpoints.
- Delete voice endpoint.
- Request retries.
- Typed errors.

### Source compatibility
- `Model` changed from an `enum` to a `struct`. Exhaustive `switch` statements over `Model` and
  uses of enum-only features (`CaseIterable`, implicit member cases) must be updated to use the
  static members of the struct.
