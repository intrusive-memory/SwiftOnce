import Foundation

public struct VoiceSettings: Sendable, Codable, Hashable {
    public var stability: Double
    public var similarityBoost: Double
    public var style: Double?
    public var speed: Double?
    public var useSpeakerBoost: Bool?

    public init(
        stability: Double = 0.5,
        similarityBoost: Double = 0.75,
        style: Double? = nil,
        speed: Double? = nil,
        useSpeakerBoost: Bool? = nil
    ) {
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.speed = speed
        self.useSpeakerBoost = useSpeakerBoost
    }

    enum CodingKeys: String, CodingKey {
        case stability
        case similarityBoost = "similarity_boost"
        case style
        case speed
        case useSpeakerBoost = "use_speaker_boost"
    }

    /// Encodes only non-nil fields for the API request body.
    internal var apiDictionary: [String: Any] {
        var dict: [String: Any] = [
            "stability": stability,
            "similarity_boost": similarityBoost,
        ]
        if let style { dict["style"] = style }
        if let speed { dict["speed"] = speed }
        if let useSpeakerBoost { dict["use_speaker_boost"] = useSpeakerBoost }
        return dict
    }
}
