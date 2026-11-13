// ARMOR-IOS-CONTROL - takes the pictures of the app for the README on a simulator, against a real ARMOR-SERVER that the workflow starts on the same Mac.
// Copyright (C) 2026 JuanenRac (Electro Hobby 3D). GPL-3.0-or-later.
// The address and the folder come from the environment (TEST_RUNNER_ARMOR_SERVER_HOST, _PORT and _SHOTS_DIR); without them every test here is skipped.
import XCTest

final class ScreenshotsUITests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment

    private func shot(_ name: String) {
        sleep(2)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder = environment["ARMOR_SHOTS_DIR"] {
            try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try? png.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
        }
    }

    func testTheLoginAndTheMainPanel() throws {
        try XCTSkipUnless(environment["ARMOR_SERVER_HOST"] != nil, "no server was given")
        let host = environment["ARMOR_SERVER_HOST"] ?? "127.0.0.1"
        let port = environment["ARMOR_SERVER_PORT"] ?? "18080"
        let app = XCUIApplication()
        app.launch()
        let server = app.textFields["login-server"]
        XCTAssertTrue(server.waitForExistence(timeout: 60), "the login did not appear")
        shot("login")
        func fill(_ field: XCUIElement, _ text: String) {
            field.tap()
            sleep(1)
            if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
                field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))   // what the field already holds goes first
            }
            field.typeText(text)
        }
        fill(server, host)
        fill(app.textFields["login-port"], port)
        fill(app.textFields["login-user"], "admin")
        fill(app.secureTextFields["login-password"], "correct-horse-battery")
        shot("login-filled")
        addUIInterruptionMonitor(withDescription: "notifications") { alert in
            for label in ["Allow", "OK"] where alert.buttons[label].exists { alert.buttons[label].tap(); return true }
            return false
        }
        app.buttons["login-submit"].tap()
        XCTAssertTrue(server.waitForNonExistence(timeout: 60), "the app did not sign in")
        sleep(6)
        app.tap()   // lets the monitor above answer the question about notifications
        sleep(2)
        shot("home")
        // the sections of the bar at the bottom
        for (label, name) in [("Alarms", "alarms"), ("Cameras", "cameras"), ("Assistant", "assistant"), ("More", "more")] {
            let tab = app.tabBars.buttons[label].exists ? app.tabBars.buttons[label] : app.buttons[label]
            if tab.exists { tab.tap(); sleep(4); shot("section-" + name) }
        }
    }
}
