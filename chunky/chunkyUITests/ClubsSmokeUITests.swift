// chunky/chunkyUITests/ClubsSmokeUITests.swift
import XCTest

final class ClubsSmokeUITests: XCTestCase {
    func testAddClubFlow() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Clubs"].tap()
        app.navigationBars.buttons["Add"].firstMatch.tap()   // leading + button label
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("7-Iron")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.textFields["7-Iron"].waitForExistence(timeout: 5))
    }
}
