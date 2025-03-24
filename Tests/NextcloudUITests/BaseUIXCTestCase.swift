// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest

@MainActor
class BaseUIXCTestCase: XCTestCase {
    var app: XCUIApplication!

    ///
    /// The Nextcloud server API abstraction object.
    ///
    var backend: UITestBackend!
    
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
    /// Let the current `Task` rest for 2 seconds.
    ///
    /// Some asynchronous background activities like the follow up request to define a download limit have no effect on the visible user interface.
    /// Hence their outcome can only be assumed after a brief period of time.
    ///
    func aSmallMoment() async throws {
        try await Task.sleep(for: .seconds(2))
    }

    ///
    /// Let the current `Task` rest for ``TestConstants/controlExistenceTimeout``.
    ///
    /// Some asynchronous background activities like the follow up request to define a download limit have no effect on the visible user interface.
    /// Hence their outcome can only be assumed after a brief period of time.
    ///
    func aMoment() async throws {
        try await Task.sleep(for: .seconds(TestConstants.controlExistenceTimeout))
    }

    ///
    /// Automation of the sign-in, if required.
    ///
    ///
    func logIn() async throws {
        guard app.buttons["login"].exists else {
            return
        }

        app.buttons["login"].tap()

        let serverAddressTextField = app.textFields["serverAddress"].firstMatch
        guard serverAddressTextField.await() else { return }

        try await aSmallMoment()

        serverAddressTextField.tap()
        serverAddressTextField.typeText(TestConstants.server)

        app.buttons["submitServerAddress"].tap()

        try await aSmallMoment()

        let webView = app.webViews.firstMatch

        guard webView.await() else {
            throw UITestError.waitForExistence(webView)
        }

//        try await aSmallMoment()

        let loginButton = webView.buttons["Log in"]

//        try await aSmallMoment()

        if loginButton.await() {
            loginButton.tap()
        }

//        try await aSmallMoment()

        let usernameTextField = webView.textFields.firstMatch

        if usernameTextField.await() {

            try await aSmallMoment()

            guard usernameTextField.await() else { return }
            usernameTextField.tap()

            try await aSmallMoment()

            usernameTextField.typeText(TestConstants.username)

            try await aSmallMoment()

            let passwordSecureTextField = webView.secureTextFields.firstMatch

            try await aSmallMoment()

            passwordSecureTextField.tap()


            try await aSmallMoment()

            passwordSecureTextField.typeText(TestConstants.password)

            try await aSmallMoment()

            webView.buttons.firstMatch.tap()
        }

        try await aSmallMoment()

        let grantButton = webView.buttons["Grant access"]

        guard grantButton.await() else {
            throw UITestError.waitForExistence(grantButton)
        }

        grantButton.tap()
        grantButton.awaitInexistence()

        app.buttons["accountSwitcher"].await()

        try await aSmallMoment()
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
}
