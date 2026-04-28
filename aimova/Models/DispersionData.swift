import Foundation

struct DispersionEllipse: Codable {
    let semiMajor: Double
    let semiMinor: Double
    let rotationDegrees: Double

    enum CodingKeys: String, CodingKey {
        case semiMajor = "semi_major"
        case semiMinor = "semi_minor"
        case rotationDegrees = "rotation_degrees"
    }
}

struct DispersionData: Codable {
    let clubId: String
    let shotShape: ShotShape
    let shotCount: Int
    let sufficientData: Bool
    let meanCarry: Double?
    let meanOffline: Double?
    let ellipse50: DispersionEllipse?
    let ellipse90: DispersionEllipse?

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case shotShape = "shot_shape"
        case shotCount = "shot_count"
        case sufficientData = "sufficient_data"
        case meanCarry = "mean_carry"
        case meanOffline = "mean_offline"
        case ellipse50 = "ellipse_50"
        case ellipse90 = "ellipse_90"
    }
}
