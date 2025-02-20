//
//  Helpers.swift
//  NextcloudUITests
//
//  Created by Milen Pivchev on 20.02.25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import XCTest

@MainActor
class BaseUIXCTestCase: XCTestCase {
    var app: XCUIApplication!

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
}
