import Foundation

public struct Voice: Sendable, Codable, Identifiable, Hashable {
    public var id: String { voiceId }

    public let voiceId: String
    public let name: String
    public let category: VoiceCategory?
    public let description: String?
    public let labels: [String: String]
    public let previewUrl: String?
    public let settings: VoiceSettings?
    public let collectionIds: [String]
    public let highQualityBaseModelIds: [String]
    public let verifiedLanguages: [VerifiedLanguage]?
    public let availableForTiers: [String]?
    public let isOwner: Bool?
    public let isLegacy: Bool?
    public let createdAtUnix: Int?

    enum CodingKeys: String, CodingKey {
        case voiceId = "voice_id"
        case name
        case category
        case description
        case labels
        case previewUrl = "preview_url"
        case settings
        case collectionIds = "collection_ids"
        case highQualityBaseModelIds = "high_quality_base_model_ids"
        case verifiedLanguages = "verified_languages"
        case availableForTiers = "available_for_tiers"
        case isOwner = "is_owner"
        case isLegacy = "is_legacy"
        case createdAtUnix = "created_at_unix"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceId = try container.decode(String.self, forKey: .voiceId)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(VoiceCategory.self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        labels = try container.decodeIfPresent([String: String].self, forKey: .labels) ?? [:]
        previewUrl = try container.decodeIfPresent(String.self, forKey: .previewUrl)
        settings = try container.decodeIfPresent(VoiceSettings.self, forKey: .settings)
        collectionIds = try container.decodeIfPresent([String].self, forKey: .collectionIds) ?? []
        highQualityBaseModelIds = try container.decodeIfPresent([String].self, forKey: .highQualityBaseModelIds) ?? []
        verifiedLanguages = try container.decodeIfPresent([VerifiedLanguage].self, forKey: .verifiedLanguages)
        availableForTiers = try container.decodeIfPresent([String].self, forKey: .availableForTiers)
        isOwner = try container.decodeIfPresent(Bool.self, forKey: .isOwner)
        isLegacy = try container.decodeIfPresent(Bool.self, forKey: .isLegacy)
        createdAtUnix = try container.decodeIfPresent(Int.self, forKey: .createdAtUnix)
    }
}

// MARK: - Verified Language

public struct VerifiedLanguage: Sendable, Codable, Hashable {
    public let language: String?
    public let modelId: String?
    public let accent: String?
    public let locale: String?
    public let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case language
        case modelId = "model_id"
        case accent
        case locale
        case previewUrl = "preview_url"
    }
}

// MARK: - Voice List Response

public struct VoiceListResponse: Sendable, Codable {
    public let voices: [Voice]
    public let hasMore: Bool
    public let totalCount: Int?
    public let nextPageToken: String?

    enum CodingKeys: String, CodingKey {
        case voices
        case hasMore = "has_more"
        case totalCount = "total_count"
        case nextPageToken = "next_page_token"
    }
}
