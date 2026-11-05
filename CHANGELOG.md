# Changelog

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
