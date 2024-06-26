//
//  BaseXCTestCase.swift
//  Nextcloud
//
//  Created by Milen on 20.03.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import XCTest
import Foundation
import Alamofire
import NextcloudKit
@testable import Nextcloud

class BaseXCTestCase: XCTestCase {
    var appToken = ""

    func setupAppToken() {
        let expectation = expectation(description: "Should get app token")

        NextcloudKit.shared.getAppPassword(serverUrl: TestConstants.server, username: TestConstants.username, password: TestConstants.password) { token, data, error in
            XCTAssertEqual(error.errorCode, 0)
            XCTAssertNotNil(token)

            guard let token else { return XCTFail() }
            
            self.appToken = token
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: TestConstants.timeoutLong)
    }

    override func setUpWithError() throws {
        setupAppToken()
    }
}
