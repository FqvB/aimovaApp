import Foundation

enum ClubType: String, Codable, CaseIterable {
    case driver = "DRIVER"
    case wood = "WOOD"
    case hybrid = "HYBRID"
    case iron = "IRON"
    case wedge = "WEDGE"
    case putter = "PUTTER"

    var displayName: String {
        switch self {
        case .driver: return "Driver"
        case .wood: return "Wood"
        case .hybrid: return "Hybrid"
        case .iron: return "Iron"
        case .wedge: return "Wedge"
        case .putter: return "Putter"
        }
    }
}

struct Club: Identifiable {
    let id: String
    let userId: String
    var name: String
    var clubType: ClubType
    var loftDegrees: Double?
    var displayOrder: Int
    var isActive: Bool
    var shotCounts: ShotCounts
    let createdAt: Date
    let updatedAt: Date
}

extension Club: Equatable {
    static func == (lhs: Club, rhs: Club) -> Bool { lhs.id == rhs.id }
}

extension Club: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Club: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name
        case userId = "user_id"
        case clubType = "club_type"
        case loftDegrees = "loft_degrees"
        case displayOrder = "display_order"
        case isActive = "is_active"
        case shotCounts = "shot_counts"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        name = try c.decode(String.self, forKey: .name)
        clubType = try c.decode(ClubType.self, forKey: .clubType)
        loftDegrees = try c.decodeIfPresent(Double.self, forKey: .loftDegrees)
        displayOrder = try c.decode(Int.self, forKey: .displayOrder)
        isActive = try c.decode(Bool.self, forKey: .isActive)
        shotCounts = try c.decodeIfPresent(ShotCounts.self, forKey: .shotCounts) ?? .empty
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
    }
}
