/// Canonical constants for ElevenLabs provider defaults.
///
/// This enum is the **single source of truth** for the default voice ID and
/// provider scheme. Downstream packages (SwiftHablare, SwiftEchada) reference
/// these constants instead of duplicating the strings.
///
/// Voice URIs follow the SwiftHablare standard: `<provider>://<voiceId>?lang=<languageCode>`
/// Example: `elevenlabs://Gsndh0O5AnuI2Hj3YUlA?lang=en`
public enum ElevenLabsDefaults {
    /// The default ElevenLabs voice ID used when no specific voice is assigned.
    public static let defaultVoiceId = "Gsndh0O5AnuI2Hj3YUlA"

    /// The provider scheme for ElevenLabs voice URIs.
    public static let providerScheme = "elevenlabs"

    /// Builds a full voice URI for the given voice ID and optional language code.
    ///
    /// Format: `elevenlabs://<voiceId>?lang=<languageCode>`
    /// When no language code is provided, the `?lang=` parameter is omitted.
    public static func voiceURI(voiceId: String, languageCode: String? = "en") -> String {
        if let languageCode {
            return "\(providerScheme)://\(voiceId)?lang=\(languageCode)"
        }
        return "\(providerScheme)://\(voiceId)"
    }

    /// Builds a full voice URI for the default voice with the given language code.
    public static func defaultVoiceURI(languageCode: String? = "en") -> String {
        voiceURI(voiceId: defaultVoiceId, languageCode: languageCode)
    }
}
