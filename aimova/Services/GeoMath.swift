import CoreLocation
import Foundation

enum GeoMath {
    private static let earthRadius = 6_371_000.0
    private static let yardsToMeters = 0.9144

    /// Returns the coordinate reached by travelling `distanceYards` from `origin` on `bearingDegrees`.
    static func destination(
        from origin: CLLocationCoordinate2D,
        distanceYards: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let d = distanceYards * yardsToMeters
        let δ = d / earthRadius
        let lat0 = origin.latitude.rad
        let lon0 = origin.longitude.rad
        let θ = bearingDegrees.rad

        let lat1 = asin(sin(lat0) * cos(δ) + cos(lat0) * sin(δ) * cos(θ))
        let lon1 = lon0 + atan2(sin(θ) * sin(δ) * cos(lat0), cos(δ) - sin(lat0) * sin(lat1))
        return CLLocationCoordinate2D(latitude: lat1.deg, longitude: lon1.deg)
    }

    /// Returns the initial bearing (degrees, 0–360) from `from` to `to`.
    static func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.rad
        let lat2 = to.latitude.rad
        let dLon = (to.longitude - from.longitude).rad
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x).deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Generates `pointCount` coordinates tracing the confidence ellipse defined by the given
    /// parameters, positioned along `aimBearing` from `pin`.
    ///
    /// Coordinate system: carry = along aim bearing, offline = perpendicular (positive = right).
    /// `rotationDegrees` is the angle of the ellipse's major axis from the carry axis.
    static func ellipseCoordinates(
        pin: CLLocationCoordinate2D,
        aimBearing: Double,
        meanCarry: Double,
        meanOffline: Double,
        semiMajor: Double,
        semiMinor: Double,
        rotationDegrees: Double,
        pointCount: Int = 72
    ) -> [CLLocationCoordinate2D] {
        let rot = rotationDegrees.rad
        return (0..<pointCount).map { i in
            let t = 2 * Double.pi * Double(i) / Double(pointCount)
            let carry = semiMajor * cos(t) * cos(rot) - semiMinor * sin(t) * sin(rot)
            let offline = semiMajor * cos(t) * sin(rot) + semiMinor * sin(t) * cos(rot)
            let totalCarry = meanCarry + carry
            let totalOffline = meanOffline + offline
            let p1 = destination(from: pin, distanceYards: totalCarry, bearingDegrees: aimBearing)
            return destination(from: p1, distanceYards: totalOffline, bearingDegrees: aimBearing + 90)
        }
    }
}

private extension Double {
    var rad: Double { self * .pi / 180 }
    var deg: Double { self * 180 / .pi }
}
