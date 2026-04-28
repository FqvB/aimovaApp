import Foundation

enum ShotShape: String, Codable, CaseIterable {
    case fade = "FADE"
    case draw = "DRAW"
    case straight = "STRAIGHT"

    var displayName: String {
        switch self {
        case .fade: return "Fade"
        case .draw: return "Draw"
        case .straight: return "Straight"
        }
    }

    var abbreviation: String {
        switch self {
        case .fade: return "F"
        case .draw: return "D"
        case .straight: return "S"
        }
    }
}

struct ShotCounts: Codable {
    var fade: Int
    var draw: Int
    var straight: Int

    static let empty = ShotCounts(fade: 0, draw: 0, straight: 0)

    enum CodingKeys: String, CodingKey {
        case fade = "FADE"
        case draw = "DRAW"
        case straight = "STRAIGHT"
    }

    var total: Int { fade + draw + straight }

    var displayString: String {
        guard total > 0 else { return "" }
        var parts: [String] = []
        if fade > 0 { parts.append("F:\(fade)") }
        if straight > 0 { parts.append("S:\(straight)") }
        if draw > 0 { parts.append("D:\(draw)") }
        return parts.joined(separator: "  ")
    }
}

struct Shot: Codable, Identifiable {
    let id: String
    let clubId: String
    let userId: String
    var shotShape: ShotShape
    var carryYards: Double
    var offlineYards: Double
    var totalYards: Double?
    var notes: String?
    var loggedAt: Date
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case shotShape = "shot_shape"
        case carryYards = "carry_yards"
        case offlineYards = "offline_yards"
        case totalYards = "total_yards"
        case notes
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }
}
