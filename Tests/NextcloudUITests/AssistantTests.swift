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
final class AssistantTests: BaseUIXCTestCase {
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

        try logIn()

        // Set up test backend communication.
        backend = UITestBackend()

        try await backend.assertCapability(true, capability: \.assistant)
//        try await backend.delete(testFileName)
//        try await backend.prepareTestFile(testFileName)
    }

    // MARK: - Tests

    func testCreateAssistantTask() async throws {
        let taskInput = "TestTask"
        let button = app.tabBars["Tab Bar"].buttons["More"]
        guard button.await() else { return }
        button.tap()

        let talkStaticText = app.tables.staticTexts["Assistant"]
        talkStaticText.tap()

        app.navigationBars["Assistant"].buttons["CreateButton"].tap()
                
        app.textViews["InputTextEditor"].typeText(taskInput)
        app.navigationBars["New Free text to text prompt task"]/*@START_MENU_TOKEN@*/.buttons["Create"]/*[[".otherElements[\"Create\"].buttons[\"Create\"]",".buttons[\"Create\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        
        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)

        pullToRefresh()

        try await aMoment()

        XCTAssert(cell.staticTexts[taskInput].exists)

    }

    func testEditAssistantTask() async throws {
        try await testCreateAssistantTask()

        let taskInputEdited = "TestTask"

//        XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0).buttons["TestTask, This is a fake result: \n\n- Prompt: TestTask\n- Model: model_2\n- Maximum number of words: 1234, Today"]/*@START_MENU_TOKEN@*/.press(forDuration: 1.5);/*[[".tap()",".press(forDuration: 1.5);"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0)/*@START_MENU_TOKEN@*/.staticTexts["This is a fake result: \n\n- Prompt: TestTask\n- Model: model_2\n- Maximum number of words: 1234"].press(forDuration: 1.3);/*[[".buttons[\"TestTask, This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234, Today\"].staticTexts[\"This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234\"]",".tap()",".press(forDuration: 1.3);",".staticTexts[\"This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234\"]"],[[[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
//        XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0).buttons["TestTask, This is a fake result: \n\n- Prompt: TestTask\n- Model: model_2\n- Maximum number of words: 1234, Today"].tap()
//

        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)

        XCUIApplication().tabBars["Tab Bar"].buttons["More"].tap()
//        XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0)/*@START_MENU_TOKEN@*/.staticTexts["This is a fake result: \n\n- Prompt: TestTask\n- Model: model_2\n- Maximum number of words: 1234"].press(forDuration: 2.1);/*[[".buttons[\"TestTask, This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234, Today\"].staticTexts[\"This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234\"]",".tap()",".press(forDuration: 2.1);",".buttons[\"TaskContextMenu\"].staticTexts[\"This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234\"]",".staticTexts[\"This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234\"]"],[[[-1,4,1],[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
//                XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0)/*@START_MENU_TOKEN@*/.staticTexts["TestTask"].press(forDuration: 2.2);/*[[".buttons[\"TestTask, This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234, Today\"].staticTexts[\"TestTask\"]",".tap()",".press(forDuration: 2.2);",".buttons[\"TaskContextMenu\"].staticTexts[\"TestTask\"]",".staticTexts[\"TestTask\"]"],[[[-1,4,1],[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
        XCUIApplication().collectionViews.children(matching: .cell).element(boundBy: 0)/*@START_MENU_TOKEN@*/.staticTexts["TestTask"].press(forDuration: 1.7);/*[[".buttons[\"TestTask, This is a fake result: \\n\\n- Prompt: TestTask\\n- Model: model_2\\n- Maximum number of words: 1234, Today\"].staticTexts[\"TestTask\"]",".tap()",".press(forDuration: 1.7);",".buttons[\"TaskContextMenu\"].staticTexts[\"TestTask\"]",".staticTexts[\"TestTask\"]"],[[[-1,4,1],[-1,3,1],[-1,0,1]],[[-1,2],[-1,1]]],[0,0]]@END_MENU_TOKEN@*/
//        XCUIApplication().sheets.scrollViews.otherElements.buttons["Delete"].tap()
        print(app.debugDescription)

        let editButton = app.otherElements.containing(.staticText, identifier: "Edit").firstMatch
            XCTAssertTrue(editButton.waitForExistence(timeout: 2), "Edit button not found in context menu")
            editButton.tap()

    }

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
