//
//  NextcloudUITests.swift
//  NextcloudUITests
//
//  Created by Milen Pivchev on 5/16/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

@testable import Nextcloud
import XCTest


// NOTE: Make sure to keep the directory structure of the thing you are testing the same as the original.
// For example: the Login code is inside iOSClient/Login, therefore this test is also inside a iOSClient/Login direcotry.
final class LoginUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
    }
}
