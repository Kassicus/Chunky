// chunky/chunkyTests/SessionModelTests.swift
import XCTest
import SwiftData
@testable import chunky

@MainActor
final class SessionModelTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Club.self, Shot.self, Session.self, CalibrationProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testSessionCascadesShotDeletion() throws {
        let ctx = try makeContext()
        let session = Session(date: Date(timeIntervalSince1970: 0), location: "Range",
                              lens: .telephoto, temperatureC: 15, altitudeM: 0, humidity: 0)
        ctx.insert(session)
        let shot = Shot(timestamp: Date(timeIntervalSince1970: 0), ballSpeedMS: 70,
                        launchAngleDeg: 11, azimuthDeg: 0, spinRPM: 2600, spinSource: .modeled,
                        spinAxisTiltDeg: 0, carryMeters: 240, confidence: .high)
        shot.session = session
        ctx.insert(shot)
        try ctx.save()
        ctx.delete(session)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Shot>()).count, 0) // cascaded
    }

    func testCalibrationProfileStores() throws {
        let ctx = try makeContext()
        ctx.insert(CalibrationProfile(lens: .telephoto, pxPerMeter: 1200,
                                      imageUpX: 0, imageUpY: 1, cameraDistanceM: 3))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<CalibrationProfile>()).first?.lens, .telephoto)
    }
}
