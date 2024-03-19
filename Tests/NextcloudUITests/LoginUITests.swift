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
        serverAddressHttpsTextField.typeText(baseUrl)
        let button = app.windows.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 0)
        button.tap()

        let webViewsQuery = app.webViews.webViews.webViews
        let loginButton2 = webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(loginButton2.waitForExistence(timeout: timeoutSeconds))
        waitForEnabledAndHittable(object: loginButton2)
        loginButton2.tap()

        //        let element = webViewsQuery/*@START_MENU_TOKEN@*/.otherElements["main"]/*[[".otherElements[\"Login – Nextcloud\"].otherElements[\"main\"]",".otherElements[\"main\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.children(matching: .other).element(boundBy: 1)
        let usernameTextField = webViewsQuery/*@START_MENU_TOKEN@*/.textFields["Login with username or email"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].textFields[\"Login with username or email\"]",".textFields[\"Login with username or email\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        XCTAssert(usernameTextField.waitForExistence(timeout: timeoutSeconds))
        usernameTextField.tap()
        usernameTextField.typeText(user)
        let passwordTextField = webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        passwordTextField.tap()
        passwordTextField.typeText(user)
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


        //            let app = XCUIApplication()
        //            app.buttons["Log in"].tap()
        //
        //            let serverAddressHttpsTextField = app.textFields["Server address https:// …"]
        //            serverAddressHttpsTextField.tap()
        //            serverAddressHttpsTextField.tap()
        //            serverAddressHttpsTextField.tap()
        //            serverAddressHttpsTextField.tap()
        //            serverAddressHttpsTextField.tap()
        //
        //            let webViewsQuery = app.webViews.webViews.webViews
        //            webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        //
        //            let loginWithUsernameOrEmailTextField = webViewsQuery/*@START_MENU_TOKEN@*/.textFields["Login with username or email"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].textFields[\"Login with username or email\"]",".textFields[\"Login with username or email\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
        //            loginWithUsernameOrEmailTextField.tap()
        //            webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Log in to Nextcloud"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"]",".otherElements[\"Log in to Nextcloud\"].staticTexts[\"Log in to Nextcloud\"]",".staticTexts[\"Log in to Nextcloud\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        //            webViewsQuery/*@START_MENU_TOKEN@*/.staticTexts["Forgot password?"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"]",".links[\"Forgot password?\"].staticTexts[\"Forgot password?\"]",".staticTexts[\"Forgot password?\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/.tap()
        //            loginWithUsernameOrEmailTextField.tap()
        //            loginWithUsernameOrEmailTextField.tap()
        //            webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        //            webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        //            webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Grant access"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Grant access\"]",".buttons[\"Grant access\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
        //            app.collectionViews.otherElements.containing(.staticText, identifier:"2 folders").element.tap()
        //

        
//        let app = XCUIApplication()
//        app.buttons["Log in"].tap()
//        app.textFields["Server address https:// …"].tap()
//        
//        let webViewsQuery2 = app.webViews.webViews.webViews
//        let logInButton = webViewsQuery2/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
//        logInButton.tap()
//        
//        let loginWithUsernameOrEmailTextField = webViewsQuery2/*@START_MENU_TOKEN@*/.textFields["Login with username or email"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].textFields[\"Login with username or email\"]",".textFields[\"Login with username or email\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
//        loginWithUsernameOrEmailTextField.tap()
//        
//        let logInToNextcloudStaticText = webViewsQuery2/*@START_MENU_TOKEN@*/.staticTexts["Log in to Nextcloud"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"]",".otherElements[\"Log in to Nextcloud\"].staticTexts[\"Log in to Nextcloud\"]",".staticTexts[\"Log in to Nextcloud\"]"],[[[-1,3],[-1,2],[-1,1,2],[-1,0,1]],[[-1,3],[-1,2],[-1,1,2]],[[-1,3],[-1,2]]],[0]]@END_MENU_TOKEN@*/
//        logInToNextcloudStaticText.tap()
//        logInToNextcloudStaticText.tap()
//        
//        let logInButton2 = webViewsQuery2/*@START_MENU_TOKEN@*/.buttons["Log in"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].buttons[\"Log in\"]",".buttons[\"Log in\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/
//        logInButton2.tap()
//        app.navigationBars["localhost"].buttons["Back"].tap()
//        app.children(matching: .window).element(boundBy: 0).children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .other).element.children(matching: .button).element(boundBy: 0).tap()
//        logInButton.tap()
//        logInToNextcloudStaticText.tap()
//        logInToNextcloudStaticText.tap()
//        loginWithUsernameOrEmailTextField.tap()
//        
//        let webViewsQuery = webViewsQuery2
//        webViewsQuery/*@START_MENU_TOKEN@*/.secureTextFields["Password"]/*[[".otherElements[\"Login – Nextcloud\"]",".otherElements[\"main\"].secureTextFields[\"Password\"]",".secureTextFields[\"Password\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
//        logInButton2.tap()
//        webViewsQuery/*@START_MENU_TOKEN@*/.buttons["Grant access"]/*[[".otherElements.matching(identifier: \"Nextcloud\")",".otherElements[\"main\"].buttons[\"Grant access\"]",".buttons[\"Grant access\"]"],[[[-1,2],[-1,1],[-1,0,1]],[[-1,2],[-1,1]]],[0]]@END_MENU_TOKEN@*/.tap()
                
    }
}
