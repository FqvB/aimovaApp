import Foundation
import Combine
import SwiftUI

@MainActor
final class BagViewModel: ObservableObject {
    @Published var activeClubs: [Club] = []
    @Published var inactiveClubs: [Club] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api = APIClient.shared

    func loadClubs() async {
        isLoading = true
        errorMessage = nil
        do {
            let all: [Club] = try await api.get("/api/v1/clubs")
            activeClubs = all.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
            inactiveClubs = all.filter { !$0.isActive }.sorted { $0.displayOrder < $1.displayOrder }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addClub(name: String, clubType: ClubType, loftDegrees: Double?) async {
        let nextOrder = (activeClubs.map(\.displayOrder).max() ?? -1) + 1
        do {
            let club: Club = try await api.post(
                "/api/v1/clubs",
                body: ClubCreateBody(
                    name: name,
                    clubType: clubType,
                    loftDegrees: loftDegrees,
                    displayOrder: nextOrder
                )
            )
            activeClubs.append(club)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deactivateClub(id: String) async {
        do {
            try await api.delete("/api/v1/clubs/\(id)")
            if let idx = activeClubs.firstIndex(where: { $0.id == id }) {
                var club = activeClubs.remove(at: idx)
                club.isActive = false
                inactiveClubs.append(club)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reactivateClub(id: String) async {
        let nextOrder = (activeClubs.map(\.displayOrder).max() ?? -1) + 1
        do {
            let updated: Club = try await api.put(
                "/api/v1/clubs/\(id)",
                body: ClubUpdateBody(displayOrder: nextOrder, isActive: true)
            )
            inactiveClubs.removeAll { $0.id == id }
            activeClubs.append(updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorderClubs(fromOffsets: IndexSet, toOffset: Int) async {
        activeClubs.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for index in activeClubs.indices {
            activeClubs[index].displayOrder = index
        }
        let items = activeClubs.map { ClubReorderBody(clubId: $0.id, displayOrder: $0.displayOrder) }
        do {
            let updated: [Club] = try await api.put("/api/v1/clubs/reorder", body: items)
            activeClubs = updated.sorted { $0.displayOrder < $1.displayOrder }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ClubCreateBody: Encodable {
    let name: String
    let clubType: ClubType
    let loftDegrees: Double?
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case name
        case clubType = "club_type"
        case loftDegrees = "loft_degrees"
        case displayOrder = "display_order"
    }
}

struct ClubUpdateBody: Encodable {
    var name: String? = nil
    var clubType: ClubType? = nil
    var loftDegrees: Double? = nil
    var displayOrder: Int? = nil
    var isActive: Bool? = nil

    enum CodingKeys: String, CodingKey {
        case name
        case clubType = "club_type"
        case loftDegrees = "loft_degrees"
        case displayOrder = "display_order"
        case isActive = "is_active"
    }
}

struct ClubReorderBody: Encodable {
    let clubId: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case displayOrder = "display_order"
    }
}
