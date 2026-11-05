import Foundation

/// One entry from `GET /v1/models`.
public struct ModelInfo: Sendable, Codable, Identifiable, Equatable {
    public let modelId: String
    public let name: String?
    public let canDoTextToSpeech: Bool?
    public let canDoVoiceConversion: Bool?
    public let canBeFinetuned: Bool?
    public let canUseStyle: Bool?
    public let canUseSpeakerBoost: Bool?
    public let maximumTextLengthPerRequest: Int?
    public let modelRates: ModelRates?

    public var id: String { modelId }
    public var characterCostMultiplier: Double? { modelRates?.characterCostMultiplier }

    public struct ModelRates: Sendable, Codable, Equatable {
        public let characterCostMultiplier: Double?
        enum CodingKeys: String, CodingKey { case characterCostMultiplier = "character_cost_multiplier" }
    }

    enum CodingKeys: String, CodingKey {
        case modelId = "model_id"
        case name
        case canDoTextToSpeech = "can_do_text_to_speech"
        case canDoVoiceConversion = "can_do_voice_conversion"
        case canBeFinetuned = "can_be_finetuned"
        case canUseStyle = "can_use_style"
        case canUseSpeakerBoost = "can_use_speaker_boost"
        case maximumTextLengthPerRequest = "maximum_text_length_per_request"
        case modelRates = "model_rates"
    }
}

/// `GET /v1/user/subscription`.
public struct Subscription: Sendable, Codable, Equatable {
    public let tier: String?
    public let status: String?
    public let characterCount: Int?
    public let characterLimit: Int?
    public let voiceLimit: Int?
    public let voiceSlotsUsed: Int?
    public let professionalVoiceLimit: Int?
    public let canUseInstantVoiceCloning: Bool?
    public let nextCharacterCountResetUnix: Int?

    public var charactersRemaining: Int? {
        guard let characterLimit, let characterCount else { return nil }
        return characterLimit - characterCount
    }

    public var voiceSlotsFree: Int? {
        guard let voiceLimit, let voiceSlotsUsed else { return nil }
        return voiceLimit - voiceSlotsUsed
    }

    enum CodingKeys: String, CodingKey {
        case tier, status
        case characterCount = "character_count"
        case characterLimit = "character_limit"
        case voiceLimit = "voice_limit"
        case voiceSlotsUsed = "voice_slots_used"
        case professionalVoiceLimit = "professional_voice_limit"
        case canUseInstantVoiceCloning = "can_use_instant_voice_cloning"
        case nextCharacterCountResetUnix = "next_character_count_reset_unix"
    }
}

/// Audio plus the `request-id` response header, for continuity chaining
/// (`previousRequestIds` / `nextRequestIds`, max 3 each).
public struct SpeechResult: Sendable {
    public let audio: Data
    /// `nil` when served from the local audio cache or the header was absent.
    public let requestId: String?
}
