import Foundation
import Combine
import SwiftUI
import CoreLocation

struct EllipseOverlay: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    let fillOpacity: Double
    let strokeOpacity: Double
}

extension ShotShape {
    var overlayColor: Color {
        switch self {
        case .fade: return .blue
        case .straight: return .green
        case .draw: return .orange
        }
    }
}

@MainActor
final class MapViewModel: ObservableObject {
    @Published var aimCoordinate: CLLocationCoordinate2D?
    @Published var selectedClubId: String?
    @Published var activeShapes: Set<ShotShape> = [.fade, .straight, .draw]
    @Published var dispersionByClub: [String: [ShotShape: DispersionData]] = [:]
    @Published var isLoadingDispersion = false

    private let api = APIClient.shared

    func toggleClub(_ clubId: String) async {
        if selectedClubId == clubId {
            selectedClubId = nil
            return
        }
        selectedClubId = clubId
        guard dispersionByClub[clubId] == nil else { return }
        isLoadingDispersion = true
        do {
            let responses: [DispersionData] = try await api.get("/api/v1/dispersion/\(clubId)")
            dispersionByClub[clubId] = Dictionary(uniqueKeysWithValues: responses.map { ($0.shotShape, $0) })
        } catch {
            // No data → no ellipses shown; not a fatal error
        }
        isLoadingDispersion = false
    }

    func toggleShape(_ shape: ShotShape) {
        if activeShapes.contains(shape) {
            activeShapes.remove(shape)
        } else {
            activeShapes.insert(shape)
        }
    }

    func dispersionForSelectedClub() -> [ShotShape: DispersionData]? {
        guard let id = selectedClubId else { return nil }
        return dispersionByClub[id]
    }

    func ellipseOverlays(pin: CLLocationCoordinate2D) -> [EllipseOverlay] {
        guard let aimCoord = aimCoordinate,
              let clubId = selectedClubId,
              let dispDict = dispersionByClub[clubId] else { return [] }

        let bearing = GeoMath.bearing(from: pin, to: aimCoord)
        var overlays: [EllipseOverlay] = []

        for shape in ShotShape.allCases where activeShapes.contains(shape) {
            guard let data = dispDict[shape],
                  data.sufficientData,
                  let meanCarry = data.meanCarry,
                  let meanOffline = data.meanOffline,
                  let e90 = data.ellipse90,
                  let e50 = data.ellipse50 else { continue }

            overlays.append(EllipseOverlay(
                id: "\(clubId)_\(shape.rawValue)_90",
                coordinates: GeoMath.ellipseCoordinates(
                    pin: pin, aimBearing: bearing,
                    meanCarry: meanCarry, meanOffline: meanOffline,
                    semiMajor: e90.semiMajor, semiMinor: e90.semiMinor,
                    rotationDegrees: e90.rotationDegrees
                ),
                color: shape.overlayColor, fillOpacity: 0.15, strokeOpacity: 0.6
            ))
            overlays.append(EllipseOverlay(
                id: "\(clubId)_\(shape.rawValue)_50",
                coordinates: GeoMath.ellipseCoordinates(
                    pin: pin, aimBearing: bearing,
                    meanCarry: meanCarry, meanOffline: meanOffline,
                    semiMajor: e50.semiMajor, semiMinor: e50.semiMinor,
                    rotationDegrees: e50.rotationDegrees
                ),
                color: shape.overlayColor, fillOpacity: 0.35, strokeOpacity: 0.0
            ))
        }
        return overlays
    }

    func aimLineCoordinates(pin: CLLocationCoordinate2D) -> [CLLocationCoordinate2D]? {
        guard let aimCoord = aimCoordinate else { return nil }
        let bearing = GeoMath.bearing(from: pin, to: aimCoord)
        let far = GeoMath.destination(from: pin, distanceYards: 350, bearingDegrees: bearing)
        return [pin, far]
    }

    func shotCountLabel(for shape: ShotShape) -> String? {
        guard let id = selectedClubId,
              let data = dispersionByClub[id]?[shape] else { return nil }
        if data.sufficientData { return nil }
        return "\(data.shotCount)/\(DispersionEngine.minimumShots)"
    }
}
