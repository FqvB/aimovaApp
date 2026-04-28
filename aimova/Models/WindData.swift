import Foundation

struct WindData: Codable {
    let windSpeedMph: Double
    let windDirectionDegrees: Double
    let windGustsMph: Double
    let fetchedAt: Date

    enum CodingKeys: String, CodingKey {
        case windSpeedMph = "wind_speed_mph"
        case windDirectionDegrees = "wind_direction_degrees"
        case windGustsMph = "wind_gusts_mph"
        case fetchedAt = "fetched_at"
    }
}
