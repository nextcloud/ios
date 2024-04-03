//
//  NextcloudUITests.swift
//  NextcloudUITests
//
//  Created by Milen Pivchev on 5/19/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import XCTest
import NextcloudKit
@testable import Nextcloud

final class LoginUITests: BaseUIXCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        app.launchArguments += ["UI_TESTING"]
    }

    func test_logIn_withProperParams_shouldLogInAndGoToHomeScreen() throws {
        app.launch()

        let loginButton = app.buttons["Log in"]
        XCTAssert(loginButton.waitForExistence(timeout: timeoutSeconds))
        loginButton.tap()

        let serverAddressHttpsTextField = app.textFields["Server address https:// …"]
        serverAddressHttpsTextField.tap()
        serverAddressHttpsTextField.typeText(TestConstants.server)
        let button = app.windows.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 0)
        button.tap()

        let webViewsQuery = app.webViews.webViews.webViews
        let loginButton2 = webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(loginButton2.waitForExistence(timeout: timeoutSeconds))
        waitForEnabledAndHittable(object: loginButton2)
        loginButton2.tap()

        let usernameTextField = webViewsQuery.textFields["Login with username or email"]
//        usernameTextField.waitUntilExists().tap()
//        UIPasteboard.general.string = TestConstants.username
//        usernameTextField.press(forDuration: 1.3)
//        app.menuItems["Paste"].tap()
//        app.keys["a"].tap()
//        app.keys["d"].tap()
//        app.keys["m"].tap()
//        app.keys["i"].tap()
//        app.keys["n"].tap()
//        waitUntilElementHasFocus(element: usernameTextField).typeText(TestConstants.username)
//        XCTAssert(usernameTextField.waitForExistence(timeout: timeoutSeconds))
        usernameTextField.tap()
        usernameTextField.typeText(TestConstants.username)

        let passwordTextField = webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        passwordTextField.tap()
        passwordTextField.typeText(TestConstants.username)
//        passwordTextField.waitUntilExists().tap()
//        UIPasteboard.general.string = TestConstants.username
//        passwordTextField.press(forDuration: 1.3)
//        app.menuItems["Paste"].tap()
//        passwordTextField.waitUntilExists().tap()
//        app.keys["a"].tap()
//        app.keys["d"].tap()
//        app.keys["m"].tap()
//        app.keys["i"].tap()
//        app.keys["n"].tap()
//        waitUntilElementHasFocus(element: passwordTextField).typeText(TestConstants.username)

        let loginButton3 = webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(loginButton3.waitForExistence(timeout: timeoutSeconds))
        loginButton3.tap()

        let grantAccessButton = webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Grant access"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Grant access\"]",".buttons[\"Grant access\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(grantAccessButton.waitForExistence(timeout: timeoutSeconds))
        waitForEnabledAndHittable(object: grantAccessButton)
        grantAccessButton.tap()

        // Check if we are in the home screen
        XCTAssert(app.navigationBars["Nextcloud"].waitForExistence(timeout: timeoutSeconds))
        XCTAssert(app.tabBars["Tab Bar"].waitForExistence(timeout: timeoutSeconds))

        
//        let app = XCUIApplication()
//        app.windows.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.tap()
//        app.buttons["Log in"].tap()
//        app.textFields["Server address https:// …"].tap()
//        
//        let webViewsQuery = app.webViews.webViews.webViews
//        webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        
//        let logInToNextcloudStaticText = webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Log in to Nextcloud"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"]",".otherElements[\"Log in to Nextcloud\"].staticTexts[\"Log in to Nextcloud\"]",".staticTexts[\"Log in to Nextcloud\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
//        logInToNextcloudStaticText.tap()
//        logInToNextcloudStaticText.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.textFields["Login with username or email"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].textFields[\"Login with username or email\"]",".textFields[\"Login with username or email\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        
//        let pasteStaticText = app.collectionViews/*@START_MENU_TOKEN@*/.staticTexts["Paste"]/*[[".menuItems[\"Paste\"].staticTexts[\"Paste\"]",".staticTexts[\"Paste\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        pasteStaticText.tap()
//        
//        let passwordSecureTextField = webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
//        passwordSecureTextField.tap()
//        passwordSecureTextField.tap()
//        pasteStaticText.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        
//        let element = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element(boundBy: 1)
//        element.tap()
//        element.swipeUp()
//        webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Authenticate with a TOTP app"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"]",".links[\"TOTP (Authenticator app) Authenticate with a TOTP app\"]",".links.staticTexts[\"Authenticate with a TOTP app\"]",".staticTexts[\"Authenticate with a TOTP app\"]"],[[[-1,4],[-1,3],[-1,2,3],[-1,1,2],[-1,0,1]],[[-1,4],[-1,3],[-1,2,3],[-1,1,2]],[[-1,4],[-1,3],[-1,2,3]],[[-1,4],[-1,3]]],[0]]@END_MENU_TOKEN@*/.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.textFields["Authentication code"].press(forDuration: 1.1);/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].textFields[\"Authentication code\"]",".tap()",".press(forDuration: 1.1);",".textFields[\"Authentication code\"]"],[[[-1,4,2],[-1,1,2],[-1,0,1]],[[-1,4,2],[-1,1,2]],[[-1,3],[-1,2]]],[0,0]]@END_MENU_TOKEN@*/
//        pasteStaticText.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Submit"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Submit\"]",".buttons[\"Submit\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Grant access"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Grant access\"]",".buttons[\"Grant access\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        app.navigationBars["Nextcloud"].children(matching: .button).element(boundBy: 0).tap()
        
    }
}

extension XCUIElement {
    var hasFocus: Bool { value(forKey: "hasKeyboardFocus") as? Bool ?? false }

    func waitUntilExists(timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
            let elementExists = waitForExistence(timeout: timeout)
            if elementExists {
                return self
            } else {
                XCTFail("Could not find \(self) before timeout", file: file, line: line)
            }

            return self
        }
}

extension XCTestCase {
    func waitUntilElementHasFocus(element: XCUIElement, timeout: TimeInterval = 600, file: StaticString = #file, line: UInt = #line) -> XCUIElement {
        let expectation = expectation(description: "waiting for element \(element) to have focus")

        let timer = Timer(timeInterval: 1, repeats: true) { timer in
            guard element.hasFocus else { return }

            expectation.fulfill()
            timer.invalidate()
        }

        RunLoop.current.add(timer, forMode: .common)

        wait(for: [expectation], timeout: timeout)

        return element
    }
}
