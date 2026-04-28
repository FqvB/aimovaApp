import XCTest
@testable import aimova

final class DispersionEngineTests: XCTestCase {

    private func pts(_ pairs: [(Double, Double)]) -> [ShotPoint] {
        pairs.map { ShotPoint(carry: $0.0, offline: $0.1) }
    }

    private func assertClose(_ a: Double, _ b: Double, tolerance: Double = 1e-3, _ message: String = "") {
        XCTAssertEqual(a, b, accuracy: tolerance, message)
    }

    // MARK: - Minimum data threshold

    func testThreeShotsReturnsInsufficientData() {
        let result = DispersionEngine.compute(shots: pts([(150, 0), (155, 2), (145, -2)]))
        XCTAssertFalse(result.sufficientData)
        XCTAssertEqual(result.shotCount, 3)
        XCTAssertNil(result.ellipse50)
        XCTAssertNil(result.ellipse90)
    }

    func testZeroShotsReturnsInsufficientData() {
        let result = DispersionEngine.compute(shots: [])
        XCTAssertFalse(result.sufficientData)
        XCTAssertEqual(result.shotCount, 0)
    }

    // MARK: - Valid ellipse (shared test vectors with Python backend)

    func testFourShotsProducesValidEllipse() {
        let shots = pts([(150, 0), (155, 2), (145, -2), (160, 1)])
        let result = DispersionEngine.compute(shots: shots)

        XCTAssertTrue(result.sufficientData)
        XCTAssertEqual(result.shotCount, 4)

        assertClose(result.meanCarry!, 152.5)
        assertClose(result.meanOffline!, 0.25)

        let e50 = result.ellipse50!
        assertClose(e50.semiMajor, 7.7857)
        assertClose(e50.semiMinor, 1.0904)
        assertClose(e50.rotationDegrees, 12.6598)

        let e90 = result.ellipse90!
        assertClose(e90.semiMajor, 14.1903)
        assertClose(e90.semiMinor, 1.9873)
        assertClose(e90.rotationDegrees, 12.6598)

        XCTAssertGreaterThan(e90.semiMajor, e50.semiMajor)
        XCTAssertGreaterThan(e90.semiMinor, e50.semiMinor)
    }

    func testCovarianceMatrix() {
        let shots = pts([(150, 0), (155, 2), (145, -2), (160, 1)])
        let result = DispersionEngine.compute(shots: shots)
        let m = result.covarianceMatrix!

        assertClose(m[0][0], 41.6667)
        assertClose(m[1][1], 2.9167)
        assertClose(m[0][1], 9.1667)
        XCTAssertEqual(m[0][1], m[1][0], accuracy: 1e-10, "Matrix must be symmetric")
    }

    // MARK: - Degenerate cases

    func testAllIdenticalShotsDoesNotCrash() {
        let shots = pts([(150, 0), (150, 0), (150, 0), (150, 0)])
        let result = DispersionEngine.compute(shots: shots)

        XCTAssertTrue(result.sufficientData)
        XCTAssertNotNil(result.ellipse50)
        XCTAssertNotNil(result.ellipse90)
        XCTAssertGreaterThan(result.ellipse50!.semiMajor, 0)
        XCTAssertGreaterThan(result.ellipse50!.semiMinor, 0)
    }

    func testZeroOfflineVarianceEllipseAlignedWithCarryAxis() {
        let shots = pts([(150, 0), (155, 0), (145, 0), (160, 0)])
        let result = DispersionEngine.compute(shots: shots)

        XCTAssertTrue(result.sufficientData)
        let e = result.ellipse50!
        assertClose(e.rotationDegrees, 0.0, tolerance: 1e-6)
        XCTAssertGreaterThan(e.semiMajor, e.semiMinor)
    }

    func testZeroCarryVarianceEllipseAlignedWithOfflineAxis() {
        let shots = pts([(150, 0), (150, 5), (150, -5), (150, 10)])
        let result = DispersionEngine.compute(shots: shots)

        XCTAssertTrue(result.sufficientData)
        let e = result.ellipse50!
        assertClose(abs(e.rotationDegrees), 90.0, tolerance: 1e-6)
        XCTAssertGreaterThan(e.semiMajor, e.semiMinor)
    }

    // MARK: - Large dataset

    func testLargeDatasetProducesReasonableEllipse() {
        var shots: [ShotPoint] = []
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<150 {
            let carry = 150.0 + Double.random(in: -25...25, using: &rng)
            let offline = Double.random(in: -15...15, using: &rng)
            shots.append(ShotPoint(carry: carry, offline: offline))
        }
        let result = DispersionEngine.compute(shots: shots)

        XCTAssertTrue(result.sufficientData)
        XCTAssertEqual(result.shotCount, 150)

        let e50 = result.ellipse50!
        let e90 = result.ellipse90!
        XCTAssertGreaterThan(e50.semiMajor, 0)
        XCTAssertGreaterThan(e50.semiMinor, 0)
        XCTAssertGreaterThan(e90.semiMajor, e50.semiMajor)
        XCTAssertGreaterThan(e90.semiMinor, e50.semiMinor)
        XCTAssertTrue((0..<200).contains(result.meanCarry!))
    }

    // MARK: - Scale factor relationship

    func testScaleFactorRatio() {
        let shots = pts([(150, 0), (155, 2), (145, -2), (160, 1)])
        let result = DispersionEngine.compute(shots: shots)!
        let e50 = result.ellipse50!
        let e90 = result.ellipse90!

        let expectedRatio = sqrt(-2.0 * log(0.1)) / sqrt(-2.0 * log(0.5))
        assertClose(e90.semiMajor / e50.semiMajor, expectedRatio, tolerance: 1e-6)
        assertClose(e90.semiMinor / e50.semiMinor, expectedRatio, tolerance: 1e-6)
    }
}

