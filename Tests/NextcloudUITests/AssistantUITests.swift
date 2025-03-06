// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

///
/// User interface tests for the download limits management on shares.
///
@MainActor
final class AssistantUITests: BaseUIXCTestCase {
    let taskInputCreated = "TestTaskCreated" + UUID().uuidString
    let taskInputRetried = "TestTaskRetried" + UUID().uuidString
    let taskInputToEdit = "TestTaskToEdit" + UUID().uuidString
    let taskInputDeleted = "TestTaskDeleted" + UUID().uuidString

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

        try await backend.assertCapability(true, capability: \.assistant)
    }

    ///
    /// Leads to the Assistant screen.
    ///
    private func goToAssistant() {
        let button = app.tabBars["Tab Bar"].buttons["More"]
        guard button.await() else { return }
        button.tap()

        let talkStaticText = app.tables.staticTexts["Assistant"]
        talkStaticText.tap()
    }

    private func createTask(input: String) {
        app.navigationBars["Assistant"].buttons["CreateButton"].tap()

        let inputTextEditor = app.textViews["InputTextEditor"]
        inputTextEditor.await()
        inputTextEditor.typeText(input)
        app.navigationBars["New Free text to text prompt task"].buttons["Create"].tap()
    }

    private func retryTask() {
        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        cell.staticTexts[taskInputRetried].press(forDuration: 2);

        let retryButton = app.buttons["TaskRetryContextMenu"]
        XCTAssertTrue(retryButton.waitForExistence(timeout: 2), "Edit button not found in context menu")
        retryButton.tap()
    }

    private func editTask() {
        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        cell.staticTexts[taskInputToEdit].press(forDuration: 2);

        let editButton = app.buttons["TaskEditContextMenu"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 2), "Edit button not found in context menu")
        editButton.tap()

        app.textViews["InputTextEditor"].typeText("Edited")
        app.navigationBars["Edit Free text to text prompt task"].buttons["Edit"].tap()
    }

    private func deleteTask() {
        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        cell.staticTexts[taskInputDeleted].press(forDuration: 2);

        let deleteButton = app.buttons["TaskDeleteContextMenu"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "Edit button not found in context menu")
        deleteButton.tap()

        app.sheets.scrollViews.otherElements.buttons["Delete"].tap()
    }

    // MARK: - Tests

    func testCreateAssistantTask() async throws {
        goToAssistant()

        createTask(input: taskInputCreated)

        pullToRefresh()

        try await aMoment()

        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        XCTAssert(cell.staticTexts[taskInputCreated].exists)
    }

    func testRetryAssistantTask() async throws {
        goToAssistant()

        createTask(input: taskInputRetried)

        retryTask()

        pullToRefresh()

        try await aMoment()

        let matchingElements = app.collectionViews.cells.staticTexts.matching(identifier: taskInputRetried)
        print(app.collectionViews.staticTexts.debugDescription)
        XCTAssertEqual(matchingElements.count, 2, "Expected 2 elements")
    }

    func testEditAssistantTask() async throws {
        goToAssistant()

        createTask(input: taskInputToEdit)

        editTask()

        pullToRefresh()

        try await aMoment()

        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        XCTAssert(cell.staticTexts[taskInputToEdit + "Edited"].exists)
    }

    func testDeleteAssistantTask() async throws {
        goToAssistant()

        createTask(input: taskInputDeleted)

        deleteTask()

        pullToRefresh()

        try await aMoment()

        let cell = app.collectionViews.children(matching: .cell).element(boundBy: 0)
        XCTAssert(!cell.staticTexts[taskInputDeleted].exists)
    }
}
