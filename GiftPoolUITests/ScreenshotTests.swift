import XCTest

// Walks through the main screens and saves a screenshot of each one.
// Run with the GiftPoolScreenshots scheme. Set these when running from the command line:
//   TEST_RUNNER_SCREENSHOT_DIR, TEST_RUNNER_DEMO_EMAIL, TEST_RUNNER_DEMO_PASSWORD
// Optional: TEST_RUNNER_TEXT_SIZE (for example UICTContentSizeCategoryXXL) to check bigger text.
final class ScreenshotTests: XCTestCase {
    private let environment = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = true
    }

    func testWelcomeScreens() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        pause(1.5)
        save("01-welcome")

        app.buttons["Continue"].tap()
        pause(1.5)
        save("02-welcome-ideas")

        app.buttons["Continue"].tap()
        pause(1.5)
        save("03-welcome-shares")

        app.buttons["I already have an account"].tap()
        pause(2)
        save("05-sign-in")
    }

    // Short clips for the README GIFs. The screen is recorded from outside the test;
    // these marks tell the recorder where each clip starts and ends.
    func testWelcomeClip() {
        let app = XCUIApplication()
        mark("clip-start")
        app.launch()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        pause(3)
        app.buttons["Continue"].tap()
        pause(3)
        app.buttons["Continue"].tap()
        pause(3.5)
        mark("clip-end")
    }

    // Two idle screens for the README banner. A seamless loop is cut from the recording afterwards.
    func testTogetherLoop() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10))
        recordIdle(seconds: 14)
    }

    func testWelcomeBackLoop() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenWelcome", "YES"]
        app.launch()

        XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 10))
        recordIdle(seconds: 14)
    }

    // Khalid asks the group a question; the recorder posts two friends' replies after "chat-sent".
    func testChatClip() throws {
        let app = try signedInApp(emailKey: "DEMO_EMAIL")
        let poolCard = app.staticTexts["Rafi's Birthday Gift"]
        XCTAssertTrue(poolCard.waitForExistence(timeout: 20))
        dismissPasswordPrompt(in: app, timeout: 4)

        open(poolCard, expecting: app.navigationBars["Rafi's Birthday Gift"], in: app)
        app.staticTexts["Group Chat"].firstMatch.tap()
        let field = app.textViews["Message"].exists ? app.textViews["Message"] : app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        pause(2)

        mark("clip-start")
        pause(1)
        field.tap()
        pause(0.8)
        field.typeText("Who's bringing the cake on Saturday?")
        app.buttons["Send message"].tap()
        mark("chat-sent")
        pause(7)
        mark("clip-end")
    }

    // Leaves the screen to animate on its own between the clip marks.
    private func recordIdle(seconds: TimeInterval) {
        pause(1.5)
        mark("clip-start")
        pause(seconds)
        mark("clip-end")
    }

    func testTourClip() throws {
        let app = try signedInApp(emailKey: "DEMO_EMAIL")
        let poolCard = app.staticTexts["Rafi's Birthday Gift"]
        XCTAssertTrue(poolCard.waitForExistence(timeout: 20))
        dismissPasswordPrompt(in: app, timeout: 4)
        pause(1)

        mark("clip-start")
        pause(1.5)
        open(poolCard, expecting: app.navigationBars["Rafi's Birthday Gift"], in: app)
        pause(2)
        app.swipeUp()
        pause(1.5)
        app.staticTexts["Ideas & Voting"].firstMatch.tap()
        pause(2.5)
        app.swipeUp()
        pause(1.5)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
        app.staticTexts["Contributions"].firstMatch.tap()
        pause(2.5)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
        app.staticTexts["Group Chat"].firstMatch.tap()
        pause(3)
        mark("clip-end")
    }

    private func mark(_ name: String) {
        guard let folder = environment["SCREENSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: folder).appendingPathComponent(name)
        try? String(Date().timeIntervalSince1970).write(to: url, atomically: true, encoding: .utf8)
    }

    func testWelcomeBackScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenWelcome", "YES"]
        app.launch()

        guard app.buttons["Create account"].waitForExistence(timeout: 10) else { return }
        pause(1)
        save("04-welcome-back")
    }

    func testMainScreens() throws {
        let app = try signedInApp(emailKey: "DEMO_EMAIL")

        let poolCard = app.staticTexts["Rafi's Birthday Gift"]
        XCTAssertTrue(poolCard.waitForExistence(timeout: 20))
        dismissPasswordPrompt(in: app, timeout: 4)
        pause(1)
        save("06-home")

        open(poolCard, expecting: app.navigationBars["Rafi's Birthday Gift"], in: app)
        pause(2.5)
        save("07-pool-detail")

        app.swipeUp()
        pause(1)
        save("08-pool-detail-sections")

        openSection("Ideas & Voting", in: app, saveAs: "09-ideas")
        openSection("Contributions", in: app, saveAs: "10-contributions")
        openSection("Checklist", in: app, saveAs: "11-checklist")
        openSection("Group Chat", in: app, saveAs: "12-chat")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
        app.buttons["History"].tap()
        pause(1.5)
        save("13-history")
        app.buttons["Active"].tap()

        app.buttons["New Plan"].tap()
        pause(1.5)
        save("14-new-pool")
        app.swipeDown(velocity: .fast)
        pause(1)

        app.buttons["Account"].tap()
        pause(1.5)
        save("15-settings")

        app.buttons["Change avatar"].tap()
        pause(1.5)
        save("16-avatar-picker")
        app.navigationBars.buttons["Cancel"].tap()
    }

    // A 12-person plan (tools/seed_big_group.py) to check that crowded screens still lay out well.
    func testBigGroupScreens() throws {
        let app = try signedInApp(emailKey: "DEMO_EMAIL")

        let poolCard = app.staticTexts["Maliha's Wedding Gift"]
        guard poolCard.waitForExistence(timeout: 20) else {
            throw XCTSkip("Run tools/seed_big_group.py first")
        }
        open(poolCard, expecting: app.navigationBars["Maliha's Wedding Gift"], in: app)
        pause(2.5)
        save("30-group-detail")

        app.swipeUp()
        pause(1)
        save("31-group-detail-bottom")

        openSection("Ideas & Voting", in: app, saveAs: "32-group-ideas")

        app.staticTexts["Contributions"].firstMatch.tap()
        pause(2.5)
        save("33-group-contributions")
        app.swipeUp()
        pause(1)
        save("34-group-contributions-more")

        app.swipeDown()
        pause(1)
        if app.buttons["Remind All"].waitForExistence(timeout: 3) {
            app.buttons["Remind All"].tap()
            pause(1)
            save("34b-group-remind-all")
            app.alerts.buttons["Cancel"].tap()
            pause(1)
        }
        if app.buttons["Adjust Amounts"].waitForExistence(timeout: 3) {
            app.buttons["Adjust Amounts"].tap()
            pause(2)
            save("35-group-amounts")
            app.navigationBars.buttons["Cancel"].tap()
            pause(1)
        }

        // The organizer's own share is fully collected, so the sheet offers to undo it.
        app.staticTexts["Khalid"].firstMatch.tap()
        if app.navigationBars["Record Contribution"].waitForExistence(timeout: 5) {
            pause(1)
            save("35b-record-collected")
            app.navigationBars.buttons["Cancel"].tap()
            pause(1)
        }
        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)

        openSection("Group Chat", in: app, saveAs: "36-group-chat")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
        app.buttons["Account"].tap()
        pause(1.5)
        app.swipeUp()
        app.buttons["Sign Out"].tap()
        pause(1)
        save("37-sign-out-alert")
        app.alerts.buttons["Cancel"].tap()
    }

    func testMemberScreens() throws {
        let app = try signedInApp(emailKey: "MEMBER_EMAIL")

        let poolCard = app.staticTexts["Rafi's Birthday Gift"]
        XCTAssertTrue(poolCard.waitForExistence(timeout: 20))
        dismissPasswordPrompt(in: app, timeout: 4)
        pause(1)
        save("20-member-home")

        open(poolCard, expecting: app.navigationBars["Rafi's Birthday Gift"], in: app)
        pause(2.5)
        save("21-member-detail")
        openSection("Contributions", in: app, saveAs: "22-member-contributions")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reminders'")).firstMatch.tap()
        pause(1.5)
        save("23-member-reminders")
    }

    // Signs in with the account from the environment, signing out a previous user first.
    private func signedInApp(emailKey: String) throws -> XCUIApplication {
        let email = try XCTUnwrap(environment[emailKey], "Set TEST_RUNNER_\(emailKey)")
        let password = try XCTUnwrap(environment["DEMO_PASSWORD"], "Set TEST_RUNNER_DEMO_PASSWORD")

        let app = XCUIApplication()
        app.launchArguments = ["-hasSeenWelcome", "YES"]
        if let size = environment["TEXT_SIZE"] {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", size]
        }
        app.launch()

        if app.buttons["Account"].waitForExistence(timeout: 8) {
            app.buttons["Account"].tap()
            _ = app.navigationBars["Account"].waitForExistence(timeout: 5)
            app.swipeUp()
            app.buttons["Sign Out"].tap()

            let confirm = app.alerts.buttons["Sign Out"]
            if confirm.waitForExistence(timeout: 5) {
                confirm.tap()
            }
        }

        let signIn = app.buttons["Sign in"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10))
        signIn.tap()

        let emailField = app.textFields["Email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        emailField.typeText(email)

        // Pasting is more reliable than synthetic typing while password AutoFill is active.
        let passwordField = app.secureTextFields["Password"]
        UIPasteboard.general.string = password
        passwordField.tap()
        passwordField.press(forDuration: 1.2)
        app.menuItems["Paste"].tap()

        dismissPasswordPrompt(in: app)
        app.buttons["Sign in"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Account"].waitForExistence(timeout: 20))
        // iOS can offer to save the password a few seconds after signing in.
        dismissPasswordPrompt(in: app, timeout: 12)
        return app
    }

    // The prompt sometimes belongs to the app and sometimes to SpringBoard, so both are checked.
    private func dismissPasswordPrompt(in app: XCUIApplication, timeout: TimeInterval = 3) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let candidates = [app.buttons["Not Now"], springboard.buttons["Not Now"]]
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let button = candidates.first(where: \.exists) {
                button.tap()
                pause(1)
                return
            }
            pause(0.5)
        }
    }

    // MARK: Helpers

    // A late "Save Password?" sheet can swallow a tap, so try once more if nothing opened.
    private func open(_ element: XCUIElement, expecting screen: XCUIElement, in app: XCUIApplication) {
        element.tap()
        if !screen.waitForExistence(timeout: 4) {
            dismissPasswordPrompt(in: app, timeout: 2)
            element.tap()
            XCTAssertTrue(screen.waitForExistence(timeout: 8), "Couldn't open \(element)")
        }
    }

    private func openSection(_ title: String, in app: XCUIApplication, saveAs name: String) {
        let tile = app.staticTexts[title].firstMatch
        guard tile.waitForExistence(timeout: 5) else {
            XCTFail("Couldn't find \(title)")
            return
        }
        tile.tap()
        pause(2.5)
        save(name)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        pause(1)
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func save(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let folder = environment["SCREENSHOT_DIR"] {
            let url = URL(fileURLWithPath: folder).appendingPathComponent("\(name).png")
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}
