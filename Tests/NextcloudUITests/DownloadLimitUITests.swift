// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

///
/// User interface tests for the download limits management on shares.
///
@MainActor
final class DownloadLimitUITests: BaseUIXCTestCase {
    ///
    /// Name of the file to work with.
    ///
    /// The leading underscore is required for the file to appear at the top of the list.
    /// Obviously, this is fragile by making some assumptions of the user interface state.
    ///
    let testFileName = "_Xcode UI Test Subject.md"

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        // Handle alerts presented by the system.
        addUIInterruptionMonitor(withDescription: "Allow Notifications", for: "Allow")
        addUIInterruptionMonitor(withDescription: "Save Password", for: "Not Now")

        // Launch the app.
        app = XCUIApplication()
        app.launchArguments = ["UI_TESTING"]
        app.launch()

        try await logIn()

        // Set up test backend communication.
        backend = UITestBackend()

        try await backend.assertCapability(true, capability: \.downloadLimit)
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
