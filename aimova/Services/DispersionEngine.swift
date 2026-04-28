import Foundation

struct ShotPoint {
    let carry: Double
    let offline: Double
}

struct EllipseParams {
    let semiMajor: Double
    let semiMinor: Double
    let rotationDegrees: Double
}

struct DispersionResult {
    let shotCount: Int
    let sufficientData: Bool
    let meanCarry: Double?
    let meanOffline: Double?
    let covarianceMatrix: [[Double]]?
    let ellipse50: EllipseParams?
    let ellipse90: EllipseParams?
}

struct WindInput {
    let speedMph: Double
    let directionDegrees: Double
    let aimBearing: Double
}

enum DispersionEngine {
    static let minimumShots = 4
    private static let eps = 1e-9

    static func compute(shots: [ShotPoint]) -> DispersionResult {
        let n = shots.count
        guard n >= minimumShots else {
            return DispersionResult(
                shotCount: n, sufficientData: false,
                meanCarry: nil, meanOffline: nil,
                covarianceMatrix: nil, ellipse50: nil, ellipse90: nil
            )
        }

        let carries = shots.map(\.carry)
        let offlines = shots.map(\.offline)

        let meanCarry = carries.reduce(0, +) / Double(n)
        let meanOffline = offlines.reduce(0, +) / Double(n)

        let varCarry = max(
            carries.map { pow($0 - meanCarry, 2) }.reduce(0, +) / Double(n - 1),
            eps
        )
        let varOffline = max(
            offlines.map { pow($0 - meanOffline, 2) }.reduce(0, +) / Double(n - 1),
            eps
        )
        let cov = zip(carries, offlines)
            .map { (c, o) in (c - meanCarry) * (o - meanOffline) }
            .reduce(0, +) / Double(n - 1)

        let a = varCarry
        let b = cov
        let d = varOffline

        let discriminant = sqrt(max(0, pow(a - d, 2) + 4 * b * b))
        let lambda1 = (a + d + discriminant) / 2
        let lambda2 = max((a + d - discriminant) / 2, eps)

        let vx: Double
        let vy: Double
        if abs(b) > eps {
            vx = b
            vy = lambda1 - a
        } else if a >= d {
            vx = 1.0
            vy = 0.0
        } else {
            vx = 0.0
            vy = 1.0
        }

        let rotationDegrees = atan2(vy, vx) * (180.0 / .pi)

        func ellipse(confidence: Double) -> EllipseParams {
            let s = sqrt(-2.0 * log(1.0 - confidence))
            return EllipseParams(
                semiMajor: s * sqrt(lambda1),
                semiMinor: s * sqrt(lambda2),
                rotationDegrees: rotationDegrees
            )
        }

        return DispersionResult(
            shotCount: n,
            sufficientData: true,
            meanCarry: meanCarry,
            meanOffline: meanOffline,
            covarianceMatrix: [[a, b], [b, d]],
            ellipse50: ellipse(confidence: 0.5),
            ellipse90: ellipse(confidence: 0.9)
        )
    }

    static func applyWind(to result: DispersionResult, wind: WindInput) -> DispersionResult {
        guard result.sufficientData,
              let meanCarry = result.meanCarry,
              let meanOffline = result.meanOffline,
              let e50 = result.ellipse50,
              let e90 = result.ellipse90 else { return result }

        let angleRad = (wind.directionDegrees - wind.aimBearing) * .pi / 180.0
        let headwindMph = wind.speedMph * cos(angleRad)
        let crosswindMph = wind.speedMph * sin(angleRad)

        let adjustedCarry: Double
        if headwindMph > 0 {
            adjustedCarry = meanCarry * (1.0 - 0.01 * headwindMph)
        } else {
            adjustedCarry = meanCarry * (1.0 + 0.005 * abs(headwindMph))
        }

        let offlineShift = 0.005 * meanCarry * crosswindMph
        let adjustedOffline = meanOffline + offlineShift

        let widthFactor = headwindMph > 0 ? (1.0 + 0.02 * headwindMph) : 1.0

        func widened(_ e: EllipseParams) -> EllipseParams {
            EllipseParams(semiMajor: e.semiMajor, semiMinor: e.semiMinor * widthFactor, rotationDegrees: e.rotationDegrees)
        }

        return DispersionResult(
            shotCount: result.shotCount,
            sufficientData: true,
            meanCarry: adjustedCarry,
            meanOffline: adjustedOffline,
            covarianceMatrix: result.covarianceMatrix,
            ellipse50: widened(e50),
            ellipse90: widened(e90)
        )
    }
}
