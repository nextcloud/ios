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
        let button = app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 0)
        button.tap()

        let webViewsQuery = app.webViews.webViews.webViews
        let loginButton2 = webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(loginButton2.waitForExistence(timeout: timeoutSeconds))
        waitForEnabledAndHittable(object: loginButton2)
        loginButton2.tap()

        let usernameTextField = webViewsQuery.textFields["Login with username or email"]
        XCTAssert(usernameTextField.waitForExistence(timeout: timeoutSeconds))
        usernameTextField.tap()
        usernameTextField.typeText(TestConstants.username)

        let passwordTextField = webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(passwordTextField.waitForExistence(timeout: timeoutSeconds))
        passwordTextField.tap()
        passwordTextField.typeText(TestConstants.username)

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
//        app.buttons["Log in"]/*@START_MENU_TOKEN@*/.press(forDuration: 22.5);/*[[".tap()",".press(forDuration: 22.5);"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        
//        let serverAddressHttpsTextField = app.textFields["Server address https:// …"]
//        serverAddressHttpsTextField.tap()
//        
//        let lKey = app/*@START_MENU_TOKEN@*/.keys["l"]/*[[".keyboards.keys[\"l\"]",".keys[\"l\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        lKey.tap()
//        lKey.tap()
//        
//        let oKey = app/*@START_MENU_TOKEN@*/.keys["o"]/*[[".keyboards.keys[\"o\"]",".keys[\"o\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        oKey.tap()
//        oKey.tap()
//        
//        let cKey = app/*@START_MENU_TOKEN@*/.keys["c"]/*[[".keyboards.keys[\"c\"]",".keys[\"c\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        cKey.tap()
//        cKey.tap()
//        
//        let aKey = app/*@START_MENU_TOKEN@*/.keys["a"]/*[[".keyboards.keys[\"a\"]",".keys[\"a\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
//        aKey.tap()
//        aKey.tap()
//        app.alerts["Connection error"].scrollViews.otherElements.buttons["OK"].tap()
//        serverAddressHttpsTextField.tap()
//        app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 0).tap()
        
    }
}
