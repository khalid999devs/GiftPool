import XCTest

// Drives the real app through every main flow against the local Firebase emulator.
// An organizer and a member are created fresh on each run, so the test can repeat.
final class EndToEndTests: XCTestCase {
    private var app: XCUIApplication!

    // Accounts made by this test only exist in the local emulator.
    private let password = "e2e-pass-123"
    private let stamp = String(Int(Date().timeIntervalSince1970))

    private var organizerEmail: String { "e2e-org-\(stamp)@example.com" }
    private var memberEmail: String { "e2e-mem-\(stamp)@example.com" }
    private var poolTitle: String { "E2E Gift \(stamp)" }

    private let organizerName = "Omar Organizer"
    private let memberName = "Mina Member"

    override func setUp() {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["-useEmulator", "-hasSeenWelcome", "YES"]
        app.launch()
    }

    func testWholeGiftJourney() {
        signOutIfSignedIn()

        // 1. Organizer creates the plan
        signUp(name: organizerName, email: organizerEmail)
        createPool()

        // 2-5. Organizer plans the gift
        ideasAndVoting()
        checklist()
        sendChatMessage("Hello from the organizer")
        editThenUnsend("Wrong plan, sorry")

        // 6. Organizer reads the invite code
        let code = readInviteCode()
        goHome()
        signOut()

        // 7. Member joins with the code and says hi
        signUp(name: memberName, email: memberEmail)
        joinPool(code: code)
        sendChatMessage("Hi, Mina here")
        goHome()
        signOut()

        // 3 + 8. Organizer assigns amounts, records their own share and reminds the member
        signIn(email: organizerEmail)
        openPool()
        assignAndRecord()
        remindMember()
        goHome()
        signOut()

        // 7. Member sees the reminder and reports giving
        signIn(email: memberEmail)
        checkMemberReminder()
        openPool()
        reportGiven()
        goHome()
        signOut()

        // 8. Organizer confirms the money
        signIn(email: organizerEmail)
        openPool()
        confirmMemberMoney()

        // 9. Purchased, delivered, celebration, History
        finishPlan()

        // 10. Settings
        changeDisplayName(to: "Omar Planner")
        signOut()
    }

    // MARK: Steps

    private func createPool() {
        XCTContext.runActivity(named: "Create pool") { _ in
            tap(button(startingWith: "Start a gift"))

            type(poolTitle, into: input("Plan title"))
            type("Rafi", into: input("Recipient's name"))
            type("6000", into: input("Target budget, in taka"))

            tap(app.navigationBars.buttons["Create"])
            allowNotificationsIfAsked()

            // The new plan opens straight away.
            XCTAssertTrue(app.navigationBars[poolTitle].waitForExistence(timeout: 15), "Pool detail did not open after Create")
            XCTAssertTrue(text(containing: "For Rafi").waitForExistence(timeout: 5))
        }
    }

    private func ideasAndVoting() {
        XCTContext.runActivity(named: "Ideas & Voting") { _ in
            openSection("Ideas & Voting")

            addIdea(title: "Instant camera", price: "5500", link: "https://example.com/instant-camera")
            XCTAssertTrue(text(containing: "example.com").waitForExistence(timeout: 8), "Product link not shown")

            tap(app.buttons["Vote"])
            XCTAssertTrue(app.buttons["Voted"].waitForExistence(timeout: 8), "Vote was not recorded")
            XCTAssertTrue(text(containing: "1 vote").waitForExistence(timeout: 5))

            tap(app.buttons["Pick This Gift"])
            confirmDialog("Pick")
            XCTAssertTrue(text(containing: "Picked").waitForExistence(timeout: 8), "Pick did not show")

            // Edit the picked idea
            tap(app.buttons["More actions for Instant camera"])
            tap(app.buttons["Edit"])
            clearAndType("Instant camera kit", into: input("Gift name, e.g. Instant camera"))
            tap(app.navigationBars.buttons["Save"])
            XCTAssertTrue(app.buttons["More actions for Instant camera kit"].waitForExistence(timeout: 8), "Edited title not shown")

            // Add a second idea and delete it
            addIdea(title: "Board game", price: "3000")
            tap(app.buttons["More actions for Board game"])
            tap(app.buttons["Delete"])
            confirmDialog("Delete")
            XCTAssertTrue(waitToDisappear(app.buttons["More actions for Board game"]), "Deleted idea is still visible")

            goBack()
        }
    }

    private func addIdea(title: String, price: String, link: String? = nil) {
        tap(app.navigationBars.buttons["Suggest an Idea"])
        type(title, into: input("Gift name, e.g. Instant camera"))
        type(price, into: input("Estimated price, in taka"))
        if let link {
            type(link, into: input("https://"))
        }
        tap(app.navigationBars.buttons["Add"])
        XCTAssertTrue(app.buttons["More actions for \(title)"].waitForExistence(timeout: 10), "Idea \(title) did not appear")
    }

    private func checklist() {
        XCTContext.runActivity(named: "Checklist") { _ in
            openSection("Checklist")

            // Add a task assigned to me with a due date
            let title = "Buy wrapping paper"
            tap(app.navigationBars.buttons["Add task"])
            type(title, into: input("e.g. Wrap the gift"))

            tap(button(startingWith: "Assigned to"))
            tap(app.buttons["Me"])

            let dueToggle = app.switches["Set a due date"]
            tap(dueToggle)
            if dueToggle.value as? String == "0" {
                dueToggle.switches.firstMatch.tap()
            }
            tap(app.navigationBars.buttons["Add"])

            let row = app.cells.containing(.staticText, identifier: title).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10), "New task did not appear")
            XCTAssertTrue(row.staticTexts["You"].exists, "Task is not shown as assigned to me")

            // Mark it done
            tap(row.buttons["Mark done"])
            XCTAssertTrue(row.buttons["Mark not done"].waitForExistence(timeout: 8), "Task was not marked done")

            // Delete it with a swipe. A long swipe deletes straight away; a short one shows the button.
            row.swipeLeft()
            let delete = app.buttons["Delete"]
            if delete.waitForExistence(timeout: 2) {
                delete.tap()
            }
            XCTAssertTrue(waitToDisappear(row), "Deleted task is still visible")

            goBack()
        }
    }

    private func sendChatMessage(_ message: String) {
        XCTContext.runActivity(named: "Chat: \(message)") { _ in
            openSection("Group Chat")
            send(message)
            goBack()
        }
    }

    // Long-press your own bubble (on the right) to edit it, then to unsend it for everyone.
    private func editThenUnsend(_ message: String) {
        XCTContext.runActivity(named: "Edit and unsend: \(message)") { _ in
            openSection("Group Chat")
            send(message)

            longPressBubble(containing: message)
            tap(app.buttons["Edit"])
            XCTAssertTrue(app.staticTexts["Editing message"].waitForExistence(timeout: 5), "Edit mode did not open")
            // The text is back in the message box, which still has focus.
            app.typeText("!")
            tap(app.buttons["Save edit"])
            XCTAssertTrue(app.staticTexts["Edited"].waitForExistence(timeout: 10), "Message was not edited")

            longPressBubble(containing: message)
            tap(app.buttons["Unsend"])
            confirmDialog("Unsend")
            XCTAssertTrue(text(containing: "You unsent a message").waitForExistence(timeout: 10), "Message was not unsent")
            XCTAssertFalse(text(containing: message).exists, "The unsent text is still showing")

            goBack()
        }
    }

    private func longPressBubble(containing message: String) {
        text(containing: message).coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).press(forDuration: 1)
    }

    private func send(_ message: String) {
        type(message, into: input("Message"))
        tap(app.buttons["Send message"])

        XCTAssertTrue(text(containing: message).waitForExistence(timeout: 10), "Message did not appear")
        XCTAssertTrue(waitToDisappear(text(containing: "Sending"), timeout: 10), "Message is stuck in Sending…")
        XCTAssertFalse(app.buttons["Retry"].exists, "Message failed to send")
    }

    private func readInviteCode() -> String {
        XCTContext.runActivity(named: "Read invite code") { _ in
            tap(app.buttons["Plan options"])
            tap(app.buttons["Invite Friends"])

            let codeText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Invitation code '")).firstMatch
            guard codeText.waitForExistence(timeout: 10) else {
                XCTFail("Invite code not shown")
                return ""
            }

            // The label reads "Invitation code A B C D - E F ..."; strip the spaces.
            let code = codeText.label
                .replacingOccurrences(of: "Invitation code ", with: "")
                .replacingOccurrences(of: " ", with: "")
            XCTAssertEqual(code.count, 19, "Unexpected code format: \(code)")
            XCTAssertTrue(text(containing: "Valid until").waitForExistence(timeout: 5), "Invite expiry not shown")

            tap(app.navigationBars.buttons["Close"])
            return code
        }
    }

    private func joinPool(code: String) {
        XCTContext.runActivity(named: "Join with code") { _ in
            tap(button(startingWith: "Join with a code"))
            type(code, into: input("Invitation code"))
            tap(app.buttons["Find Plan"])

            XCTAssertTrue(text(containing: poolTitle).waitForExistence(timeout: 10), "Invite preview not shown")
            tap(app.buttons["Join Plan"])
            allowNotificationsIfAsked()

            XCTAssertTrue(app.navigationBars[poolTitle].waitForExistence(timeout: 15), "Pool did not open after joining")
        }
    }

    private func assignAndRecord() {
        XCTContext.runActivity(named: "Assign and record") { _ in
            // The next-step card splits the budget in one tap.
            tap(button(startingWith: "Split Equally"))
            confirmDialog("Split")
            XCTAssertTrue(text(containing: "contributions outstanding").waitForExistence(timeout: 10), "Equal split not saved")

            openSection("Contributions")
            XCTAssertTrue(app.buttons["Adjust Amounts"].waitForExistence(timeout: 10), "Assignments not saved")

            // The organizer is listed first; record their own share by typing it.
            tap(app.buttons["Record"].firstMatch)
            clearAndType("3000", into: input("Total received, in taka"))
            tap(app.navigationBars.buttons["Save"])
            XCTAssertTrue(waitToDisappear(app.navigationBars["Record Contribution"]), "Record sheet did not close")
            XCTAssertTrue(text(containing: "1 of 2 settled").exists || text(containing: "Collected").exists)
        }
    }

    private func remindMember() {
        XCTContext.runActivity(named: "Private reminder") { _ in
            let remind = app.buttons["Remind"]
            guard remind.waitForExistence(timeout: 5) else {
                XCTFail("Remind button missing")
                return
            }
            XCTAssertTrue(remind.isEnabled, "Remind should be allowed while the member owes money")
            tap(remind)
            tap(app.buttons["Send Reminder"])
            XCTAssertTrue(waitToDisappear(app.buttons["Send Reminder"]), "Reminder sheet did not close")

            // A second reminder is blocked for 24 hours.
            XCTAssertTrue(text(containing: "Reminded once").waitForExistence(timeout: 8), "Reminder was not sent")
            XCTAssertFalse(app.buttons["Remind"].isEnabled, "Remind should cool down after sending")

            goBack()
        }
    }

    private func checkMemberReminder() {
        XCTContext.runActivity(named: "Member sees reminder") { _ in
            let bell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Reminders, 1 unread'")).firstMatch
            XCTAssertTrue(bell.waitForExistence(timeout: 10), "Member's bell does not show the reminder")
        }
    }

    private func reportGiven() {
        XCTContext.runActivity(named: "I Have Given") { _ in
            XCTAssertTrue(text(containing: "Your share").waitForExistence(timeout: 10), "Member's share card missing")
            tap(app.buttons["I Have Given"])
            confirmDialog("I Have Given")
            XCTAssertTrue(text(containing: "Waiting for the organizer").waitForExistence(timeout: 10), "Report not saved")
        }
    }

    private func confirmMemberMoney() {
        XCTContext.runActivity(named: "Organizer confirms") { _ in
            openSection("Contributions")

            XCTAssertTrue(text(containing: "\(memberName) says they've given").waitForExistence(timeout: 10), "Member's report not visible")
            tap(app.buttons["Confirm"])
            tap(button(startingWith: "Mark Fully Collected"))
            XCTAssertTrue(waitToDisappear(app.navigationBars["Record Contribution"]), "Confirm sheet did not close")

            // Nothing is owed now, so Remind is gone.
            XCTAssertTrue(waitToDisappear(app.buttons["Remind"], timeout: 8), "Remind should be gone once fully collected")

            goBack()
        }
    }

    private func finishPlan() {
        XCTContext.runActivity(named: "Statuses") { _ in
            // Once everything is collected, the next-step card offers the status change.
            tap(app.buttons["Mark as Purchased"])
            confirmDialog("Mark as Purchased")
            XCTAssertTrue(text(containing: "Deliver the gift").waitForExistence(timeout: 10), "Status did not move to Purchased")

            tap(app.buttons["Mark as Delivered"])
            confirmDialog("Mark as Delivered")

            XCTAssertTrue(app.staticTexts["Gift delivered!"].waitForExistence(timeout: 10), "Celebration did not show")
            tap(app.buttons["Done"])

            goHome()
            tap(app.segmentedControls.buttons["History"])
            XCTAssertTrue(text(containing: poolTitle).waitForExistence(timeout: 10), "Plan is not in History")
            tap(app.segmentedControls.buttons["Active"])
        }
    }

    private func changeDisplayName(to newName: String) {
        XCTContext.runActivity(named: "Settings") { _ in
            tap(app.buttons["Account"])
            clearAndType(newName, into: input("Display name"))
            tap(app.buttons["Save"])
            XCTAssertTrue(app.images["Saved"].waitForExistence(timeout: 10), "Name was not saved")
            tap(app.navigationBars.buttons["Close"])
            XCTAssertTrue(text(containing: "Hi, Omar").waitForExistence(timeout: 5))
        }
    }

    // MARK: Account helpers

    // The two accounts are created straight in the Auth emulator: iOS password AutoFill keeps
    // popping up over a brand-new password field, which makes typing one unreliable in UI tests.
    // Everything after that goes through the real screens.
    private func signUp(name: String, email: String) {
        XCTContext.runActivity(named: "Create account \(email)") { _ in
            createAccountInEmulator(name: name, email: email)
            signIn(email: email)
        }
    }

    private func signIn(email: String) {
        XCTContext.runActivity(named: "Sign in \(email)") { _ in
            openAuthScreen("Sign in", expecting: input("Email"))
            type(email, into: input("Email"))
            pastePassword(password, into: app.secureTextFields["Password"])
            dismissPasswordPrompts()
            tap(app.buttons["Sign in"].firstMatch)

            XCTAssertTrue(app.buttons["Account"].waitForExistence(timeout: 20), "Sign in did not reach Home")
            dismissPasswordPrompts()
        }
    }

    private func createAccountInEmulator(name: String, email: String) {
        let url = URL(string: "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "password": password,
            "displayName": name
        ])

        let done = expectation(description: "Create \(email)")
        URLSession.shared.dataTask(with: request) { _, response, _ in
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200, "Emulator sign-up failed")
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 10)
    }

    private func signOut() {
        XCTContext.runActivity(named: "Sign out") { _ in
            // Right after launch the app can still be busy, so try the Account button twice.
            for _ in 0..<2 where !app.navigationBars["Account"].exists {
                tap(app.buttons["Account"])
                _ = app.navigationBars["Account"].waitForExistence(timeout: 8)
            }
            XCTAssertTrue(app.navigationBars["Account"].exists, "Settings did not open")
            app.swipeUp()
            tap(app.buttons["Sign Out"])
            confirmDialog("Sign Out")
            XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 10), "Sign out did not return to Welcome back")
        }
    }

    // The Welcome back links sometimes ignore a tap made during the screen's entrance animation, so try twice.
    private func openAuthScreen(_ link: String, expecting field: XCUIElement) {
        for _ in 0..<2 {
            tap(app.buttons[link])
            if field.waitForExistence(timeout: 4) {
                return
            }
        }
    }

    private func signOutIfSignedIn() {
        let account = app.buttons["Account"]
        let welcome = app.buttons["Create account"]
        _ = account.waitForExistence(timeout: 8) || welcome.exists
        if account.exists {
            signOut()
        }
    }

    // The app asks for notification permission after creating or joining a plan.
    private func allowNotificationsIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Allow'")).firstMatch
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
            pause(1)
        }
    }

    // MARK: Navigation helpers

    private func openPool() {
        tap(text(containing: poolTitle))
        XCTAssertTrue(app.navigationBars[poolTitle].waitForExistence(timeout: 10), "Pool did not open")
    }

    private func openSection(_ title: String) {
        let tile = button(startingWith: title)
        if !tile.waitForExistence(timeout: 5) || !tile.isHittable {
            app.swipeUp()
        }
        tap(tile)
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 8), "\(title) did not open")
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.waitForExistence(timeout: 3) {
            back.tap()
        }
        pause(0.8)
    }

    // Taps back until the Home screen (with its Plans picker) is showing.
    private func goHome() {
        for _ in 0..<5 {
            if app.segmentedControls.buttons["Active"].exists && app.buttons["Account"].isHittable {
                return
            }
            goBack()
        }
    }

    // MARK: Element helpers

    // A text field or multi-line text view, found by its label or placeholder.
    private func input(_ label: String) -> XCUIElement {
        let types = [XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue]
        let predicate = NSPredicate(
            format: "elementType IN %@ AND (label == %@ OR placeholderValue == %@ OR identifier == %@)",
            types, label, label, label
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private func button(startingWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func text(containing part: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", part)).firstMatch
    }

    private func tap(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard element.waitForExistence(timeout: 10) else {
            XCTFail("Not found: \(element)", file: file, line: line)
            print(app.debugDescription)
            return
        }
        // A system overlay window can make an element report "not hittable" even though taps reach it.
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        pause(0.6)
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // Synthetic typing into a secure field can drop characters while password AutoFill is busy,
    // so the password is pasted, like pasting from a password manager.
    private func pastePassword(_ value: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        UIPasteboard.general.string = value

        field.tap()
        field.press(forDuration: 1.2)

        let paste = app.menuItems["Paste"].exists ? app.menuItems["Paste"] : app.buttons["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 4), "Paste menu did not appear")
        paste.tap()
    }

    // iOS may offer to save or generate a password. Say no to keep the test moving.
    private func dismissPasswordPrompts() {
        let notNow = app.buttons["Not Now"]
        let close = app.buttons["Close"]
        _ = notNow.waitForExistence(timeout: 3) || close.exists

        if notNow.exists {
            notNow.tap()
            pause(0.8)
        } else if close.exists {
            close.tap()
            pause(0.8)
        }
    }

    private func type(_ value: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("Field not found: \(field)", file: file, line: line)
            print(app.debugDescription)
            return
        }
        field.tap()
        field.typeText(value)
    }

    private func clearAndType(_ value: String, into field: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        guard field.waitForExistence(timeout: 10) else {
            XCTFail("Field not found: \(field)", file: file, line: line)
            return
        }
        field.tap()
        let current = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(value)
    }

    // Confirmation dialogs repeat the label of the button that opened them, so tap the newest match.
    private func confirmDialog(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.alerts.buttons[label]
        guard button.waitForExistence(timeout: 8) else {
            XCTFail("Alert button not found: \(label)", file: file, line: line)
            print(app.debugDescription)
            return
        }
        pause(0.5)
        button.tap()
        pause(0.8)
    }

    private func waitToDisappear(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter().wait(for: [gone], timeout: timeout) == .completed
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
