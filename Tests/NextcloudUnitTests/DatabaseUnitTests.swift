//
//  NextcloudTests.swift
//  NextcloudTests
//
//  Created by Henrik Storch on 01.12.21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import XCTest
//import NextcloudKit
@testable import Nextcloud
import RealmSwift

/**
 NOTE: Please only write tests here if it's not possible to write them on NextcloudKit.
 */
class NextcloudUnitTests: XCTestCase {
    private let file1Name = "file-sample1.pdf"
    private let file2Name = "file-sample2.pdf"
    private let file3Name = "file-sample3.pdf"

    override func setUp() {
        Realm.Configuration.defaultConfiguration.inMemoryIdentifier = self.name
    }

    func testDbCreateProcessUpload_withProperParams_shouldReturnProperResult() throws {
        let bundle = Bundle(for: type(of: self))
        let metadatas = [
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file1Name, fileNameView: file1Name, ocId: NSUUID().uuidString, serverUrl: "", urlBase: "", url: "", contentType: ""),
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file2Name, fileNameView: file2Name, ocId: NSUUID().uuidString, serverUrl: "", urlBase: "", url: "", contentType: ""),
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file3Name, fileNameView: file3Name, ocId: NSUUID().uuidString, serverUrl: "", urlBase: "", url: "", contentType: ""),
        ]

        NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas, completion: { _ in })

        let result = NCManageDatabase.shared.getMetadatas(predicate: .init(value: true))

        XCTAssertEqual(metadatas, result)
    }

    func testDbCreateProcessUpload_withSameOcID_shouldOverwriteResults() throws {
        let bundle = Bundle(for: type(of: self))
        let duplicateId = NSUUID().uuidString
        let metadatas = [
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file1Name, fileNameView: file1Name, ocId: duplicateId, serverUrl: "", urlBase: "", url: "", contentType: ""),
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file2Name, fileNameView: file2Name, ocId: duplicateId, serverUrl: "", urlBase: "", url: "", contentType: ""),
            NCManageDatabase.shared.createMetadata(account: "", user: "", userId: "", fileName: file3Name, fileNameView: file3Name, ocId: duplicateId, serverUrl: "", urlBase: "", url: "", contentType: ""),
        ]

        NCNetworkingProcessUpload.shared.createProcessUploads(metadatas: metadatas, completion: { _ in })

        let result = NCManageDatabase.shared.getMetadatas(predicate: .init(value: true))

        XCTAssertNotEqual(metadatas, result)
        XCTAssertEqual(result.count, 1)
    }
}
