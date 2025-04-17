// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

///
/// User interface tests for the download limits management on shares.
///
@MainActor
final class AutoUploadUITests: BaseUIXCTestCase {
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
    }

    private func goToAutoUpload() async throws {
        addUIInterruptionMonitor(withDescription: "Are you sure you want to upload all photos?", for: "Confirm")

        app.tabBars["Tab Bar"].buttons["More"].tap()

        app.tables/*@START_MENU_TOKEN@*/.staticTexts["Settings"]/*[[".cells.staticTexts[\"Settings\"]",".staticTexts[\"Settings\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        let collectionViewsQuery = app.collectionViews
        collectionViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Auto upload"]/*[[".cells",".buttons[\"Auto upload\"].staticTexts[\"Auto upload\"]",".staticTexts[\"Auto upload\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()

        try await aSmallMoment()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow Full Access"]

        if allowButton.await() {
            allowButton.tap()
        }
    }

    func testAutoUploadAllPhotos() async throws {
        try await goToAutoUpload()

        let collectionViewsQuery = app.collectionViews

        let turnOnAutoUploadingSwitch = collectionViewsQuery.switches["Turn on auto uploading"]

        collectionViewsQuery/*@START_MENU_TOKEN@*/.switches["Auto upload photos"]/*[[".cells.switches[\"Auto upload photos\"]",".switches[\"Auto upload photos\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeUp()

        if turnOnAutoUploadingSwitch.await() {
            turnOnAutoUploadingSwitch.tap()
        }

        app.tabBars["Tab Bar"].buttons["Files"].tap()

        try await aSmallMoment()

        pullToRefresh()

        let photosItem = app.collectionViews["NCCollectionViewCommon"]/*@START_MENU_TOKEN@*/.staticTexts["Photos"]/*[[".cells[\"Photos\"].staticTexts[\"Photos\"]",".cells[\"Cell\/Photos\"].staticTexts[\"Photos\"]",".staticTexts[\"Photos\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        if photosItem.await() {
            photosItem.tap()
        }

        try await aSmallMoment()
        
        XCTAssertTrue(app.collectionViews.cells.count == 6)
    }

    func testAutoUploadNewPhotos() async throws {
        try await goToAutoUpload()

        let backUpNewPhotosVideosOnlySwitch = app.collectionViews.switches["NewPhotosToggle"]

        if backUpNewPhotosVideosOnlySwitch.await() {
            backUpNewPhotosVideosOnlySwitch.switches.firstMatch.tap()
        }

        let collectionViewsQuery = app.collectionViews

        let turnOnAutoUploadingSwitch = collectionViewsQuery.switches["Turn on auto uploading"]

        collectionViewsQuery/*@START_MENU_TOKEN@*/.switches["Auto upload photos"]/*[[".cells.switches[\"Auto upload photos\"]",".switches[\"Auto upload photos\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.swipeUp()

        if turnOnAutoUploadingSwitch.await() {
            turnOnAutoUploadingSwitch.tap()
        }

        app.tabBars["Tab Bar"].buttons["Files"].tap()

        try await aSmallMoment()

        pullToRefresh()

        let photosItem = app.collectionViews["NCCollectionViewCommon"]/*@START_MENU_TOKEN@*/.staticTexts["Photos"]/*[[".cells[\"Photos\"].staticTexts[\"Photos\"]",".cells[\"Cell\/Photos\"].staticTexts[\"Photos\"]",".staticTexts[\"Photos\"]"],[[[-1,2],[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/

        // Does not seem possible to take a screenshot on Simulator or easily transfer a new photo in Simulator.
        // Thus for now we can only rely on the Photos folder not existing at all to test this.
        XCTAssertFalse(photosItem.exists)
    }

    override func tearDown() async throws {
        let tabBar = app.tabBars["Tab Bar"]
        tabBar.buttons["Files"].tap()
        let nccollectionviewcommonCollectionView = app.collectionViews["NCCollectionViewCommon"]
        let cell = nccollectionviewcommonCollectionView/*@START_MENU_TOKEN@*/.cells["Cell/Photos"]/*[[".cells[\"Photos\"]",".cells[\"Cell\/Photos\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        if !cell.exists { return }

        cell.otherElements.containing(.button, identifier:"Cell/Photos/shareButton").children(matching: .button).element(boundBy: 1).tap()
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.staticTexts["Delete folder"]/*[[".cells.staticTexts[\"Delete folder\"]",".staticTexts[\"Delete folder\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        app.alerts["Delete folder?"].scrollViews.otherElements.buttons["Yes"].tap()

        cell.awaitInexistence()
    }
}
