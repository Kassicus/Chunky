// chunky/chunkyTests/ExposureCalculatorTests.swift
import XCTest
@testable import chunky

final class ExposureCalculatorTests: XCTestCase {
    func testScalesISOToPreserveExposure() {
        // auto: ISO 100 at 1/120 s. Target 1/2000 s is 16.67× shorter → ISO ~1667.
        let r = ExposureCalculator.recommend(autoISO: 100, autoDuration: 1.0/120,
                                             targetDuration: 1.0/2000, minISO: 20, maxISO: 3000)
        XCTAssertEqual(r.iso, 100 * (1.0/120) / (1.0/2000), accuracy: 1e-6) // ≈ 1666.7
        XCTAssertFalse(r.needsMoreLight)
    }

    func testClampsAndWarnsWhenTooDark() {
        let r = ExposureCalculator.recommend(autoISO: 400, autoDuration: 1.0/60,
                                             targetDuration: 1.0/2000, minISO: 20, maxISO: 3000)
        // ideal = 400 * (1/60)/(1/2000) = 400 * 33.33 = 13333 > 3000 → clamp + warn
        XCTAssertEqual(r.iso, 3000, accuracy: 1e-6)
        XCTAssertTrue(r.needsMoreLight)
    }

    func testClampsToMinISO() {
        let r = ExposureCalculator.recommend(autoISO: 20, autoDuration: 1.0/2200,
                                             targetDuration: 1.0/2000, minISO: 25, maxISO: 3000)
        // ideal < minISO → clamp up to minISO, not "more light"
        XCTAssertEqual(r.iso, 25, accuracy: 1e-6)
        XCTAssertFalse(r.needsMoreLight)
    }
}
