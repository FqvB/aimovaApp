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
    var isGhost: Bool = false
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

    @Published var windData: WindData?
    @Published var windFetchFailed = false
    @Published var showRawEllipses = false

    @Published var tournamentMode: Bool = UserDefaults.standard.bool(forKey: "tournament_mode") {
        didSet {
            UserDefaults.standard.set(tournamentMode, forKey: "tournament_mode")
            if tournamentMode {
                stopWindUpdates()
                windData = nil
                windFetchFailed = false
            } else if let loc = windLocation {
                startWindUpdates(coordinate: loc)
            }
        }
    }

    private let api = APIClient.shared
    private var windTask: Task<Void, Never>?
    private var windLocation: CLLocationCoordinate2D?
    private var tournamentModeObserver: Any?

    init() {
        tournamentModeObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            let stored = UserDefaults.standard.bool(forKey: "tournament_mode")
            if stored != self.tournamentMode {
                self.tournamentMode = stored
            }
        }
    }

    deinit {
        if let obs = tournamentModeObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

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
            // No data → no ellipses; not a fatal error
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

    func startWindUpdates(coordinate: CLLocationCoordinate2D) {
        guard !tournamentMode else { return }
        windLocation = coordinate
        windTask?.cancel()
        windTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchWind()
                try? await Task.sleep(for: .seconds(300))
            }
        }
    }

    func stopWindUpdates() {
        windTask?.cancel()
        windTask = nil
    }

    private func fetchWind() async {
        guard let loc = windLocation else { return }
        do {
            let data: WindData = try await api.get(
                "/api/v1/wind?lat=\(loc.latitude)&lon=\(loc.longitude)"
            )
            windData = data
            windFetchFailed = false
        } catch {
            windFetchFailed = true
        }
    }

    func ellipseOverlays(pin: CLLocationCoordinate2D) -> [EllipseOverlay] {
        guard let aimCoord = aimCoordinate,
              let clubId = selectedClubId,
              let dispDict = dispersionByClub[clubId] else { return [] }

        let bearing = GeoMath.bearing(from: pin, to: aimCoord)
        var overlays: [EllipseOverlay] = []

        for shape in ShotShape.allCases where activeShapes.contains(shape) {
            guard let data = dispDict[shape], data.sufficientData else { continue }

            let rawResult = data.toDispersionResult()

            guard let rawCarry = rawResult.meanCarry,
                  let rawOffline = rawResult.meanOffline,
                  let rawE50 = rawResult.ellipse50,
                  let rawE90 = rawResult.ellipse90 else { continue }

            let showWind = !tournamentMode && windData != nil
            let result: DispersionResult

            if showWind, let wind = windData {
                result = DispersionEngine.applyWind(
                    to: rawResult,
                    wind: WindInput(
                        speedMph: wind.windSpeedMph,
                        directionDegrees: wind.windDirectionDegrees,
                        aimBearing: bearing
                    )
                )
            } else {
                result = rawResult
            }

            guard let adjCarry = result.meanCarry,
                  let adjOffline = result.meanOffline,
                  let adjE50 = result.ellipse50,
                  let adjE90 = result.ellipse90 else { continue }

            if showWind && showRawEllipses {
                overlays.append(EllipseOverlay(
                    id: "\(clubId)_\(shape.rawValue)_raw_90",
                    coordinates: GeoMath.ellipseCoordinates(
                        pin: pin, aimBearing: bearing,
                        meanCarry: rawCarry, meanOffline: rawOffline,
                        semiMajor: rawE90.semiMajor, semiMinor: rawE90.semiMinor,
                        rotationDegrees: rawE90.rotationDegrees
                    ),
                    color: shape.overlayColor, fillOpacity: 0, strokeOpacity: 0.5,
                    isGhost: true
                ))
                overlays.append(EllipseOverlay(
                    id: "\(clubId)_\(shape.rawValue)_raw_50",
                    coordinates: GeoMath.ellipseCoordinates(
                        pin: pin, aimBearing: bearing,
                        meanCarry: rawCarry, meanOffline: rawOffline,
                        semiMajor: rawE50.semiMajor, semiMinor: rawE50.semiMinor,
                        rotationDegrees: rawE50.rotationDegrees
                    ),
                    color: shape.overlayColor, fillOpacity: 0, strokeOpacity: 0.3,
                    isGhost: true
                ))
            }

            overlays.append(EllipseOverlay(
                id: "\(clubId)_\(shape.rawValue)_90",
                coordinates: GeoMath.ellipseCoordinates(
                    pin: pin, aimBearing: bearing,
                    meanCarry: adjCarry, meanOffline: adjOffline,
                    semiMajor: adjE90.semiMajor, semiMinor: adjE90.semiMinor,
                    rotationDegrees: adjE90.rotationDegrees
                ),
                color: shape.overlayColor, fillOpacity: 0.15, strokeOpacity: 0.6
            ))
            overlays.append(EllipseOverlay(
                id: "\(clubId)_\(shape.rawValue)_50",
                coordinates: GeoMath.ellipseCoordinates(
                    pin: pin, aimBearing: bearing,
                    meanCarry: adjCarry, meanOffline: adjOffline,
                    semiMajor: adjE50.semiMajor, semiMinor: adjE50.semiMinor,
                    rotationDegrees: adjE50.rotationDegrees
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
