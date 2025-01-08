// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

///
/// User interface tests for the download limits management on shares.
///
/// > To Do: Check whether this can be converted to Swift Testing.
///
@MainActor
final class DownloadLimitTests: XCTestCase {
    var app: XCUIApplication!

    ///
    /// The Nextcloud server API abstraction object.
    ///
    var backend: UITestBackend!

    ///
    /// Name of the file to work with.
    ///
    /// The leading underscore is required for the file to appear at the top of the list.
    /// Obviously, this is fragile by making some assumptions of the user interface state.
    ///
    let testFileName = "_Xcode UI Test Subject.md"

    // MARK: - Helpers

    ///
    /// Generic convenience method to define user interface interruption monitors.
    ///
    /// This is called every time an alert from outside the app's user interface is presented (in example system prompt about saving a password).
    /// Then the button is tapped defined by the given `label`.
    ///
    /// - Parameters:
    ///     - description: The human readable description for the monitor to create.
    ///     - label: The localized text on the alert action to tap.
    ///
    /// > Important: This is a candidate for outsourcing into a dedicated library, if not NextcloudKit.
    ///
    func addUIInterruptionMonitor(withDescription description: String, for label: String) {
        addUIInterruptionMonitor(withDescription: description) { alert in
            let button = alert.buttons[label]

            if button.exists {
                button.tap()
                return true
            }

            return false
        }
    }

    ///
    /// Let the current `Task` rest for ``TestConstants/controlExistenceTimeout``.
    ///
    /// Some asynchronous background activities like the follow up request to define a download limit have no effect on the visible user interface.
    /// Hence their outcome can only be assumed after a brief period of time.
    ///
    /// The odd name may stick out but reads natural in an `try await aMoment()`.
    ///
    func aMoment() async throws {
        try await Task.sleep(for: .seconds(TestConstants.controlExistenceTimeout))
    }

    ///
    /// Pull to refresh on the first found collection view to reveal the new file on the server.
    ///
    func pullToRefresh(file: StaticString = #file, line: UInt = #line) {
        let cell = app.collectionViews.firstMatch.staticTexts.firstMatch

        guard cell.exists else {
            XCTFail("Apparently no collection view cell is visible!", file: file, line: line)
            return
        }

        let start = cell.coordinate(withNormalizedOffset: CGVectorMake(0, 0))
        let finish = cell.coordinate(withNormalizedOffset: CGVectorMake(0, 20))

        start.press(forDuration: 0.2, thenDragTo: finish)
    }

    ///
    /// Automation of the sign-in, if required.
    ///
    /// > Important: This is a candidate for outsourcing into a dedicated library, if not NextcloudKit.
    ///
    func logIn() throws {
        guard app.buttons["login"].exists else {
            return
        }

        app.buttons["login"].tap()

        let serverAddressTextField = app.textFields["serverAddress"].firstMatch
        guard serverAddressTextField.await() else { return }

        serverAddressTextField.tap()
        serverAddressTextField.typeText(TestConstants.server)

        app.buttons["submitServerAddress"].tap()

        let webView = app.webViews.firstMatch

        guard webView.await() else {
            throw UITestError.waitForExistence(webView)
        }

        let loginButton = webView.buttons["Log in"]

        if loginButton.await() {
            loginButton.tap()
        }

        let usernameTextField = webView.textFields.firstMatch

        if usernameTextField.await() {
            guard usernameTextField.await() else { return }
            usernameTextField.tap()
            usernameTextField.typeText(TestConstants.username)

            let passwordSecureTextField = webView.secureTextFields.firstMatch
            passwordSecureTextField.tap()
            passwordSecureTextField.typeText(TestConstants.password)

            webView.buttons.firstMatch.tap()
        }

        let grantButton = webView.buttons["Grant access"]

        guard grantButton.await() else {
            throw UITestError.waitForExistence(grantButton)
        }

        grantButton.tap()
        grantButton.awaitInexistence()

        // Switch back from Safari to our app.
        app.activate()
        app.buttons["accountSwitcher"].await()
    }

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        // Handle alerts presented by the system.
        addUIInterruptionMonitor(withDescription: "Allow Notifications", for: "Allow")
        addUIInterruptionMonitor(withDescription: "Save Password", for: "Not Now")

        // Launch the app.
        app = XCUIApplication()
        app.launch()

        try logIn()

        // Set up test backend communication.
        backend = UITestBackend()

        try await backend.assertDownloadLimitCapability(true)
        try await backend.delete(testFileName)
        try await backend.prepareTestFile(testFileName)
    }

    // MARK: - Tests

    func testShareWithoutDownloadLimitCapability() async throws {
        // This cannot be implemented at the time of writing.
        // There is no way to disable and enable server apps via web API.
        // The Xcode UI test process cannot access Docker.
        throw XCTSkip("Not implemented yet!")
    }

    func testNewShareWithoutDownloadLimit() async throws {
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]

        guard shareButton.exists else {
            throw UITestError.waitForExistence(shareButton)
        }

        shareButton.tap()

        // Tap add share link button.

        let addShareLinkButton = app.buttons["addShareLink"]
        guard addShareLinkButton.await() else { return }
        addShareLinkButton.tap()

        // Tap confirm share button.

        let confirmShareButton = app.buttons["confirmShare"]

        guard confirmShareButton.exists else {
            throw UITestError.waitForExistence(confirmShareButton)
        }

        confirmShareButton.tap()
        confirmShareButton.awaitInexistence()

        // Then
        let shares = try await backend.getShares(byPath: "/\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await backend.assertNoDownloadLimit(by: token)
    }

    func testNewShareWithDownloadLimit() async throws {
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap add share link button.

        let addShareLinkButton = app.buttons["addShareLink"]
        guard addShareLinkButton.await() else { return }
        addShareLinkButton.tap()

        // Tap download limits.

        let downloadLimitCell = app.cells["downloadLimit"]
        guard downloadLimitCell.await() else { return }
        downloadLimitCell.tap()

        // Tap download limit switch.

        let downloadLimitSwitch = app.switches["downloadLimitSwitch"]
        guard downloadLimitSwitch.await() else { return }
        downloadLimitSwitch.tap()

        // Update allowed downloads.

        let allowedDownloadsTextField = app.textFields["downloadLimitTextField"]
        guard allowedDownloadsTextField.await() else { return }
        allowedDownloadsTextField.tap()
        allowedDownloadsTextField.typeText("3")

        // Tap navigation back button.

        app.navigationBars.buttons.firstMatch.tap()

        // Tap confirm share button.

        let confirmShareButton = app.buttons["confirmShare"]
        guard confirmShareButton.await() else { return }
        confirmShareButton.tap()
        confirmShareButton.awaitInexistence()

        // Then
        let shares = try await backend.getShares(byPath: "/\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await backend.assertDownloadLimit(by: token, count: 0, limit: 3)
    }

    func testShareOfFolder() async throws {
        let testSubject = "_Xcode UI Test Subject"
        try await backend.createFolder(testSubject)
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testSubject)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap add share link button.

        let addShareLinkButton = app.buttons["addShareLink"]
        guard addShareLinkButton.await() else { return }
        addShareLinkButton.tap()

        // Verify download limits being unavailable.

        let downloadLimitCell = app.cells["downloadLimit"]
        XCTAssertFalse(downloadLimitCell.exists, "Folder shares cannot have download limits")

        // Cleanup

        try await backend.delete(testSubject)
    }

    func testAddingDownloadLimitToExistingShare() async throws {
        try await backend.createShare(byPath: testFileName)
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap show share link details button.

        let showShareLinkDetailsButton = app.buttons["showShareLinkDetails"]
        guard showShareLinkDetailsButton.await() else { return }
        showShareLinkDetailsButton.tap()

        // Tap share link details button in share menu sheet.

        let shareMenuDetailsCell = app.cells["shareMenu/details"]
        guard shareMenuDetailsCell.await() else { return }
        shareMenuDetailsCell.tap()

        // Tap download limits.

        let downloadLimitCell = app.cells["downloadLimit"]
        guard downloadLimitCell.await() else { return }
        downloadLimitCell.tap()

        // Tap download limit switch.

        let downloadLimitSwitch = app.switches["downloadLimitSwitch"]
        guard downloadLimitSwitch.await() else { return }
        downloadLimitSwitch.tap()

        // Update allowed downloads.

        let allowedDownloadsTextField = app.textFields["downloadLimitTextField"]
        guard allowedDownloadsTextField.await() else { return }
        allowedDownloadsTextField.tap()
        allowedDownloadsTextField.typeText("3")

        // Tap navigation back button.

        app.navigationBars.buttons.firstMatch.tap()

        // Tap confirm share button.

        let confirmShareButton = app.buttons["confirmShare"]
        guard confirmShareButton.await() else { return }
        confirmShareButton.tap()
        confirmShareButton.awaitInexistence()

        // Then
        let shares = try await backend.getShares(byPath: "\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await aMoment()
        try await backend.assertDownloadLimit(by: token, count: 0, limit: 3)
    }

    func testUpdatingDownloadLimitOnExistingShare() async throws {
        try await backend.createShare(byPath: testFileName)
        var shares = try await backend.getShares(byPath: testFileName)

        guard let token = shares.first?.token else {
            XCTFail("Failed to fetch token of share for test file!")
            return
        }

        try await backend.setDownloadLimit(to: 4, by: token)
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap show share link details button.

        let showShareLinkDetailsButton = app.buttons["showShareLinkDetails"]
        guard showShareLinkDetailsButton.await() else { return }
        showShareLinkDetailsButton.tap()

        // Tap share link details button in share menu sheet.

        let shareMenuDetailsCell = app.cells["shareMenu/details"]
        guard shareMenuDetailsCell.await() else { return }
        shareMenuDetailsCell.tap()

        // Tap download limits.

        let downloadLimitCell = app.cells["downloadLimit"]
        guard downloadLimitCell.await() else { return }
        downloadLimitCell.tap()

        // Check download limit switch.

        let downloadLimitSwitch = app.switches["downloadLimitSwitch"].firstMatch
        guard downloadLimitSwitch.await() else { return }

        guard let downloadLimitSwitchValue = (downloadLimitSwitch.value as? String) else {
            XCTFail("Failed to get value of user interface control!")
            return
        }

        guard downloadLimitSwitchValue == "1" else {
            XCTFail("The switch is not on!")
            return
        }

        // Check and update allowed downloads.

        let allowedDownloadsTextField = app.textFields["downloadLimitTextField"]
        guard allowedDownloadsTextField.await() else { return }

        guard let allowedDownloadsTextFieldValue = (allowedDownloadsTextField.value as? String) else {
            XCTFail("Failed to get value of user interface control!")
            return
        }

        guard allowedDownloadsTextFieldValue == "4" else {
            XCTFail("The text field value is wrong!")
            return
        }

        allowedDownloadsTextField.tap()
        allowedDownloadsTextField.typeText("6")

        // Tap navigation back button.

        app.navigationBars.buttons.firstMatch.tap()

        // Tap confirm share button.

        let confirmShareButton = app.buttons["confirmShare"]
        guard confirmShareButton.await() else { return }
        confirmShareButton.tap()
        confirmShareButton.awaitInexistence()

        // Then
        shares = try await backend.getShares(byPath: "\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await aMoment()
        try await backend.assertDownloadLimit(by: token, count: 0, limit: 6)
    }

    func testDiscardingDownloadLimitChangesOnExistingShare() async throws {
        try await backend.createShare(byPath: testFileName)
        var shares = try await backend.getShares(byPath: testFileName)

        guard let token = shares.first?.token else {
            XCTFail("Failed to fetch token of share for test file!")
            return
        }

        try await backend.setDownloadLimit(to: 8, by: token)
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap show share link details button.

        let showShareLinkDetailsButton = app.buttons["showShareLinkDetails"]
        guard showShareLinkDetailsButton.await() else { return }
        showShareLinkDetailsButton.tap()

        // Tap share link details button in share menu sheet.

        let shareMenuDetailsCell = app.cells["shareMenu/details"]
        guard shareMenuDetailsCell.await() else { return }
        shareMenuDetailsCell.tap()

        // Tap download limits.

        let downloadLimitCell = app.cells["downloadLimit"]
        guard downloadLimitCell.await() else { return }
        downloadLimitCell.tap()

        // Check download limit switch.

        let downloadLimitSwitch = app.switches["downloadLimitSwitch"].firstMatch
        guard downloadLimitSwitch.await() else { return }

        guard let downloadLimitSwitchValue = (downloadLimitSwitch.value as? String) else {
            XCTFail("Failed to get value of user interface control!")
            return
        }

        guard downloadLimitSwitchValue == "1" else {
            XCTFail("The switch is not on!")
            return
        }

        // Check and update allowed downloads.

        let allowedDownloadsTextField = app.textFields["downloadLimitTextField"]
        guard allowedDownloadsTextField.await() else { return }

        guard let allowedDownloadsTextFieldValue = (allowedDownloadsTextField.value as? String) else {
            XCTFail("Failed to get value of user interface control!")
            return
        }

        allowedDownloadsTextField.tap()
        allowedDownloadsTextField.typeText("9")

        // Tap navigation back button.

        app.navigationBars.buttons.firstMatch.tap()

        // Tap confirm share button.

        let cancelShareButton = app.buttons["cancelShare"]
        guard cancelShareButton.await() else { return }
        cancelShareButton.tap()

        // Then
        shares = try await backend.getShares(byPath: "\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await aMoment()
        try await backend.assertDownloadLimit(by: token, count: 0, limit: 8)
    }

    func testRemovingDownloadLimitFromExistingShare() async throws {
        try await backend.createShare(byPath: testFileName)
        var shares = try await backend.getShares(byPath: testFileName)

        guard let token = shares.first?.token else {
            XCTFail("Failed to fetch token of share for test file!")
            return
        }

        try await backend.setDownloadLimit(to: 4, by: token)
        pullToRefresh()

        // Tap share button.

        let shareButton = app.buttons["Cell/\(testFileName)/shareButton"]
        guard shareButton.await() else { return }
        shareButton.tap()

        // Tap show share link details button.

        let showShareLinkDetailsButton = app.buttons["showShareLinkDetails"]
        guard showShareLinkDetailsButton.await() else { return }
        showShareLinkDetailsButton.tap()

        // Tap share link details button in share menu sheet.

        let shareMenuDetailsCell = app.cells["shareMenu/details"]
        guard shareMenuDetailsCell.await() else { return }
        shareMenuDetailsCell.tap()

        // Tap download limits.

        let downloadLimitCell = app.cells["downloadLimit"]
        guard downloadLimitCell.await() else { return }
        downloadLimitCell.tap()

        // Check download limit switch.

        let downloadLimitSwitch = app.switches["downloadLimitSwitch"].firstMatch
        guard downloadLimitSwitch.await() else { return }
        downloadLimitSwitch.tap()

        // Tap navigation back button.

        app.navigationBars.buttons.firstMatch.tap()

        // Tap confirm share button.

        let confirmShareButton = app.buttons["confirmShare"]
        guard confirmShareButton.await() else { return }
        confirmShareButton.tap()
        confirmShareButton.awaitInexistence()

        // Then
        shares = try await backend.getShares(byPath: "\(testFileName)")
        XCTAssertEqual(shares.count, 1, "Only one share existing on \(testFileName)")

        guard let token = shares.first?.token else {
            throw UITestError.missingValue
        }

        try await aMoment()
        try await backend.assertDownloadLimit(by: token, count: nil, limit: nil)
    }
}
