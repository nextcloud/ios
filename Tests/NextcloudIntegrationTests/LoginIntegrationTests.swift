//
//  NextcloudIntegrationTests.swift
//  NextcloudIntegrationTests
//
//  Created by Milen Pivchev on 5/19/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import XCTest
import NextcloudKit
@testable import Nextcloud

final class LoginIntegrationTests: XCTestCase {
    private let baseUrl = EnvVars.testServerUrl
    private let user = EnvVars.testUser
    private let userId = EnvVars.testUser
    private let password = EnvVars.testAppPassword
    private lazy var account = "\(userId) \(baseUrl)"

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    override func setUp() {
        appDelegate.deleteAllAccounts()
    }

    func test_createReadDeleteFolder_withProperParams_shouldCreateReadDeleteFolder() throws {
        let expectation = expectation(description: "Should finish last callback")

        let folderName = "TestFolder10"
        let serverUrl = "\(baseUrl)/remote.php/dav/files/\(userId)"
        let serverUrlFileName = "\(serverUrl)/\(folderName)"

        NextcloudKit.shared.setup(account: account, user: user, userId: userId, password: password, urlBase: baseUrl)

        // Test creating folder
        NCNetworking.shared.createFolder(fileName: folderName, serverUrl: serverUrl, account: account, urlBase: baseUrl, userId: userId, withPush: true) { error in
            XCTAssertEqual(NKError.success.errorCode, error.errorCode)
            XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)

            Thread.sleep(forTimeInterval: 0.2)

            // Test reading folder, should exist
            NCNetworking.shared.readFolder(serverUrl: serverUrlFileName, account: self.user) { account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, metadatasDelete, error in
                XCTAssertEqual(self.account, account)
                XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)
                XCTAssertEqual(metadataFolder?.fileName, folderName)

                // Check Realm directory, should exist
                let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "serverUrl == %@", serverUrlFileName))
                XCTAssertNotNil(directory)

                Thread.sleep(forTimeInterval: 0.2)

                Task {
                    // Test deleting folder
                    await _ = NCNetworking.shared.deleteMetadata(metadataFolder!, onlyLocalCache: false)

                    XCTAssertEqual(NKError.success.errorCode, error.errorCode)
                    XCTAssertEqual(NKError.success.errorDescription, error.errorDescription)

                    try await Task.sleep(for: .milliseconds(200))

                    // Test reading folder, should NOT exist
                    NCNetworking.shared.readFolder(serverUrl: serverUrlFileName, account: self.user) { account, metadataFolder, metadatas, metadatasUpdate, metadatasLocalUpdate, metadatasDelete, error in
                        defer { expectation.fulfill() }

                        XCTAssertEqual(404, error.errorCode)
                        XCTAssertNil(metadataFolder?.fileName)

                        // Check Realm directory, should NOT exist
                        let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "serverUrl == %@", serverUrlFileName))
                        XCTAssertNil(directory)
                    }
                }


            }
        }
        
        waitForExpectations(timeout: 100)
    }
}
