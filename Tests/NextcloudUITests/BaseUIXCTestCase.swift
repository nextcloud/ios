// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-FileCopyrightText: 2026 Marino Faggiana
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

    /// Sign in through the app's authentication flow, supporting system authentication and the embedded fallback.
    func logIn() async throws {
        if app.buttons["openSidebar"].exists || app.buttons["accountSwitcher"].exists {
            return
        }
        let login = app.buttons["login"]
        guard login.await() else { throw UITestError.waitForExistence(login) }
        login.tap()

        let serverAddress = app.textFields["serverAddress"].firstMatch
        guard serverAddress.await() else { throw UITestError.waitForExistence(serverAddress) }
        serverAddress.tap()
        serverAddress.typeText(TestConstants.server)
        app.buttons["submitServerAddress"].tap()

        let webView = try await authenticationWebView()
        let username = webView.textFields.firstMatch
        let loginButton = webView.buttons["Log in"].firstMatch
        if !username.exists, loginButton.await(timeout: 5) {
            loginButton.tap()
        }
        if username.await() {
            username.tap()
            username.typeText(TestConstants.username)
            let password = webView.secureTextFields.firstMatch
            guard password.await() else { throw UITestError.waitForExistence(password) }
            password.tap()
            password.typeText(TestConstants.password)
            guard loginButton.await() else { throw UITestError.waitForExistence(loginButton) }
            loginButton.tap()
        }

        let grant = webView.buttons["Grant access"]
        guard grant.await(timeout: 30) else {
            attachAuthenticationDiagnostics()
            throw UITestError.waitForExistence(grant)
        }
        grant.tap()

        let sidebar = app.buttons["openSidebar"].firstMatch
        guard sidebar.await(timeout: 30) || app.buttons["accountSwitcher"].exists else {
            attachAuthenticationDiagnostics()
            throw UITestError.waitForExistence(sidebar)
        }
    }

    /// ASWebAuthenticationSession may expose its UI in SafariViewService rather than in the app hierarchy.
    private func authenticationWebView() async throws -> XCUIElement {
        let browsers = [app!, XCUIApplication(bundleIdentifier: "com.apple.SafariViewService")]
        let promptHosts = browsers + [XCUIApplication(bundleIdentifier: "com.apple.springboard")]
        // The app tries HTTPS first, even for the HTTP-only localhost test server.
        // Allow the initial URLSession request to time out before its HTTP fallback starts.
        let timeout = URLSessionConfiguration.default.timeoutIntervalForRequest + 30
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            for host in promptHosts where host.state != .notRunning {
                for label in ["Continue", "Allow"] {
                    let button = host.alerts.buttons[label].firstMatch
                    if button.exists && button.isHittable {
                        button.tap()
                    }
                }
            }
            for browser in browsers where browser.state != .notRunning {
                let webView = browser.webViews.firstMatch
                if webView.exists {
                    return webView
                }
            }
            try await Task.sleep(for: .milliseconds(250))
        } while Date() < deadline

        attachAuthenticationDiagnostics()
        throw UITestError.waitForExistence(app.webViews.firstMatch)
    }

    /// Keep login diagnostics in the xcresult instead of losing the context on a CI failure.
    private func attachAuthenticationDiagnostics() {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Authentication screen"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        for host in [app!, XCUIApplication(bundleIdentifier: "com.apple.SafariViewService"), XCUIApplication(bundleIdentifier: "com.apple.springboard")]
            where host.state == .runningForeground {
            let hierarchy = XCTAttachment(string: host.debugDescription)
            hierarchy.name = "Authentication UI hierarchy"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
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
