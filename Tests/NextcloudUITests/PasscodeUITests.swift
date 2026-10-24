// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

/// Exercises real settings and app-lock flows against the standard UI-test server.
@MainActor
final class PasscodeUITests: BaseUIXCTestCase {
    private let originalCode = "135790"
    private let replacementCode = "246801"
    private let wrongCode = "000000"
    private var currentCode: String?
    private let languageArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    private var title: XCUIElement { app.staticTexts["passcode.title"] }
    private var closeButton: XCUIElement { app.buttons["passcode.close"] }
    private var lockWindow: XCUIElement { app.windows["passcode.window"] }
    private var lockout: XCUIElement { app.staticTexts["passcode.lockout.remaining"] }
    private var lockSetting: XCUIElement { app.buttons["settings.passcode.toggle"] }
    private var changeSetting: XCUIElement { app.buttons["settings.passcode.change"] }

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "Allow Notifications", for: "Allow")
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_PASSCODE"] + languageArguments
        app.launch()
        try await logIn()
        openSettings()
        XCTAssertFalse(changeSetting.exists, "Each test must start with app lock disabled.")
    }

    override func tearDown() async throws {
        // Avoid leaving the simulator locked if an assertion interrupted a test.
        if let currentCode, app != nil {
            app.activate()
            if lockout.exists {
                _ = lockout.waitForNonExistence(timeout: 65)
            }
            if title.exists && !closeButton.exists {
                clearPartialCode()
                enter(currentCode)
            }
            if closeButton.exists {
                closeButton.tap()
            }
            if !lockSetting.exists {
                openSettings()
            }
            if changeSetting.exists {
                lockSetting.tap()
                enter(currentCode)
                _ = title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout)
            }
        }
        app?.terminate()
        try await super.tearDown()
    }

    func testCreateChangeAndDisablePasscode() {
        createPasscode()
        changeSetting.tap()
        assertTitle("Enter Passcode")
        enter(originalCode)
        assertTitle("Enter a new passcode")
        enter(replacementCode)
        assertTitle("Confirm new passcode")
        enter(replacementCode)
        currentCode = replacementCode
        XCTAssertTrue(title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout))

        lockSetting.tap()
        assertTitle("Enter Passcode")
        enter(originalCode)
        XCTAssertTrue(app.staticTexts["passcode.error"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["passcode.error"].label, "Incorrect passcode. Try again.")
        enter(replacementCode)
        XCTAssertTrue(title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout))
        XCTAssertFalse(changeSetting.exists)
        currentCode = nil
    }

    /// Regression for the reported brute-force bypass when disabling app lock.
    func testDisableLockoutSurvivesReopeningBackgroundAndRelaunch() {
        createPasscode()
        lockSetting.tap()
        enter(wrongCode)
        closeButton.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        lockSetting.tap()
        enter(wrongCode)
        closeButton.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        lockSetting.tap()
        enter(wrongCode)
        assertLockedOut()
        let deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds()))

        // Reopening must neither enable the keypad nor restart the countdown.
        closeButton.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        lockSetting.tap()
        assertLockedOut()
        waitForCountdown(toDropBelow: 56)
        assertOriginalDeadline(deadline)

        // Background cancels the optional request; foreground requires the mandatory lock.
        backgroundAndActivate()
        assertTitle("Enter Passcode")
        XCTAssertFalse(closeButton.exists)
        assertLockedOut()
        assertOriginalDeadline(deadline)

        // Relaunch without setup flags: credentials and the deadline must persist in Keychain.
        app.terminate()
        app.launchArguments = languageArguments
        app.launch()
        assertTitle("Enter Passcode")
        XCTAssertFalse(closeButton.exists)
        assertLockedOut()
        assertOriginalDeadline(deadline)

        XCTAssertTrue(lockout.waitForNonExistence(timeout: max(0, deadline.timeIntervalSinceNow) + 5))
        enter(originalCode)
        XCTAssertTrue(title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout))
    }

    /// Changing the code must enforce the same persisted protection as disabling it.
    func testChangePasscodeCannotResetFailedAttemptsByReopening() {
        createPasscode()
        for attempt in 1...3 {
            changeSetting.tap()
            assertTitle("Enter Passcode")
            enter(wrongCode)
            if attempt < 3 {
                closeButton.tap()
                XCTAssertTrue(title.waitForNonExistence(timeout: 5))
            }
        }
        assertLockedOut()
        let deadline = Date().addingTimeInterval(TimeInterval(remainingSeconds()))
        closeButton.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
        changeSetting.tap()
        assertLockedOut()
        assertOriginalDeadline(deadline)
    }

    func testBackgroundCannotBypassMandatoryAppLock() {
        createPasscode()
        backgroundAndActivate()
        for _ in 0..<2 {
            assertTitle("Enter Passcode")
            XCTAssertFalse(closeButton.exists)
            XCTAssertFalse(lockSetting.isHittable, "Protected settings must remain inaccessible.")
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.1, thenDragTo: end)
            XCTAssertTrue(title.exists, "Dragging must not dismiss the mandatory lock.")
            backgroundAndActivate()
        }
        enter(originalCode)
        XCTAssertTrue(title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout))
        XCTAssertTrue(lockSetting.waitForExistence(timeout: 5), "Unlocking must preserve the Settings screen.")
    }

    /// An informational sheet stays in the app window while the mandatory lock covers it.
    func testAppLockAppearsAbovePresentedSheet() {
        createPasscode()
        let acknowledgements = app.buttons["Acknowledgements"]
        scrollTo(acknowledgements)
        acknowledgements.tap()
        let close = app.buttons["settings.acknowledgements.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))

        backgroundAndActivate()
        XCTAssertTrue(lockWindow.waitForExistence(timeout: 5))
        assertTitle("Enter Passcode")
        XCTAssertFalse(close.isHittable)
        enter(originalCode)
        XCTAssertTrue(lockWindow.waitForNonExistence(timeout: 5))
        XCTAssertTrue(close.isHittable, "Unlocking must preserve the sheet underneath.")
        close.tap()
        scrollTo(lockSetting, towardsTop: true)
    }

    /// An existing confirmation alert cannot intercept or prevent the app-lock window.
    func testAppLockAppearsAbovePresentedAlert() {
        createPasscode()
        let advanced = app.buttons["Advanced"]
        scrollTo(advanced)
        advanced.tap()
        let clearCache = app.buttons["Clear cache"]
        scrollTo(clearCache)
        clearCache.tap()
        let cancel = app.alerts.firstMatch.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))

        backgroundAndActivate()
        XCTAssertTrue(lockWindow.waitForExistence(timeout: 5))
        assertTitle("Enter Passcode")
        XCTAssertFalse(cancel.isHittable)
        enter(originalCode)
        XCTAssertTrue(lockWindow.waitForNonExistence(timeout: 5))
        XCTAssertTrue(cancel.isHittable, "Unlocking must preserve the confirmation alert underneath.")
        cancel.tap()
        app.navigationBars["Advanced"].buttons["Settings"].tap()
        scrollTo(lockSetting, towardsTop: true)
    }

    /// Waiting out each three-attempt lockout must not reset the ten-attempt app-wipe counter.
    func testAppResetAfterTenFailuresAcrossLockouts() {
        createPasscode()
        let resetSetting = app.switches["settings.passcode.reset"]
        for _ in 0..<3 where !resetSetting.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(resetSetting.waitForExistence(timeout: 5))
        XCTAssertEqual(resetSetting.value as? String, "0")
        resetSetting.tap()
        XCTAssertEqual(resetSetting.value as? String, "1")

        backgroundAndActivate()
        assertTitle("Enter Passcode")
        for attempt in 1...10 {
            enter(wrongCode)
            if attempt.isMultiple(of: 3) {
                assertLockedOut()
                XCTAssertTrue(lockout.waitForNonExistence(timeout: 65))
                XCTAssertTrue(app.buttons["passcode.digit.1"].isEnabled)
            } else if attempt < 10 {
                XCTAssertTrue(title.exists, "The app must remain locked until the reset threshold.")
            }
        }

        // The real reset clears local data and exits. Relaunch without the test-setup reset.
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
        currentCode = nil
        app.launchArguments = languageArguments
        app.launch()
        XCTAssertTrue(app.buttons["login"].waitForExistence(timeout: TestConstants.controlExistenceTimeout))
        XCTAssertFalse(title.exists, "The app reset must remove the stored passcode.")
    }

    private func createPasscode() {
        lockSetting.tap()
        assertTitle("Enter a new passcode")
        enter(originalCode)
        assertTitle("Confirm new passcode")
        enter(originalCode)
        currentCode = originalCode
        XCTAssertTrue(title.waitForNonExistence(timeout: TestConstants.controlExistenceTimeout))
        XCTAssertTrue(changeSetting.waitForExistence(timeout: 5))
    }

    private func openSettings() {
        let sidebar = app.buttons["openSidebar"].firstMatch
        XCTAssertTrue(sidebar.waitForExistence(timeout: TestConstants.controlExistenceTimeout))
        sidebar.tap()
        let settings = app.buttons["sidebarSettings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        XCTAssertTrue(lockSetting.waitForExistence(timeout: 5))
    }

    private func scrollTo(_ element: XCUIElement, towardsTop: Bool = false) {
        for _ in 0..<6 where !element.isHittable {
            if towardsTop {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func enter(_ code: String) {
        for digit in code {
            let button = app.buttons["passcode.digit.\(digit)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertTrue(button.isEnabled)
            button.tap()
        }
    }

    private func clearPartialCode() {
        let delete = app.buttons["passcode.delete"]
        for _ in 0..<6 where delete.exists && delete.isEnabled {
            delete.tap()
        }
    }

    private func assertTitle(_ expected: String) {
        XCTAssertTrue(title.waitForExistence(timeout: TestConstants.controlExistenceTimeout))
        XCTAssertEqual(title.label, expected)
    }

    private func backgroundAndActivate() {
        XCUIDevice.shared.press(.home)
        let background = NSPredicate { [app] _, _ in
            MainActor.assumeIsolated { app?.state != .runningForeground }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: background, object: nil)], timeout: 5), .completed)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    private func assertLockedOut() {
        XCTAssertTrue(lockout.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["passcode.digit.1"].isEnabled)
    }

    private func remainingSeconds() -> Int {
        guard let first = lockout.label.split(separator: " ").first, let seconds = Int(first) else {
            XCTFail("Missing lockout countdown: \(lockout.label)")
            return 0
        }
        return seconds
    }

    private func waitForCountdown(toDropBelow seconds: Int) {
        let countdown = NSPredicate { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return false }
                return self.remainingSeconds() < seconds
            }
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: countdown, object: nil)], timeout: 10), .completed)
    }

    private func assertOriginalDeadline(_ deadline: Date) {
        let expected = Int(deadline.timeIntervalSinceNow.rounded(.up))
        XCTAssertGreaterThan(remainingSeconds(), 0)
        XCTAssertLessThanOrEqual(remainingSeconds(), expected + 2, "Background, reopening or relaunch must not restart the lockout.")
        XCTAssertGreaterThanOrEqual(remainingSeconds(), max(0, expected - 2), "The persisted deadline must not be shortened.")
    }
}
