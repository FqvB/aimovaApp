import Foundation
import Combine

@MainActor
final class ShotViewModel: ObservableObject {
    @Published var shots: [Shot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let clubId: String
    let clubName: String

    private let api = APIClient.shared

    init(clubId: String, clubName: String) {
        self.clubId = clubId
        self.clubName = clubName
    }

    func loadShots() async {
        isLoading = true
        errorMessage = nil
        do {
            shots = try await api.get("/api/v1/clubs/\(clubId)/shots")
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func logShot(
        shape: ShotShape,
        carry: Double,
        offline: Double,
        total: Double?,
        notes: String?,
        loggedAt: Date
    ) async throws {
        let shot: Shot = try await api.post(
            "/api/v1/clubs/\(clubId)/shots",
            body: ShotCreateBody(
                shotShape: shape,
                carryYards: carry,
                offlineYards: offline,
                totalYards: total,
                notes: notes.flatMap { $0.isEmpty ? nil : $0 },
                loggedAt: loggedAt
            )
        )
        shots.insert(shot, at: 0)
    }

    func deleteShot(id: String) async {
        do {
            try await api.delete("/api/v1/shots/\(id)")
            shots.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var shotsByShape: [(ShotShape, [Shot])] {
        ShotShape.allCases.compactMap { shape in
            let filtered = shots.filter { $0.shotShape == shape }
            return filtered.isEmpty ? nil : (shape, filtered)
        }
    }
}

private struct ShotCreateBody: Encodable {
    let shotShape: ShotShape
    let carryYards: Double
    let offlineYards: Double
    let totalYards: Double?
    let notes: String?
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case shotShape = "shot_shape"
        case carryYards = "carry_yards"
        case offlineYards = "offline_yards"
        case totalYards = "total_yards"
        case notes
        case loggedAt = "logged_at"
    }
}
