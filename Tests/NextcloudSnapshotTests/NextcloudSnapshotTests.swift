//
//  NextcloudSnapshotTests.swift
//  NextcloudSnapshotTests
//
//  Created by Milen on 06.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import XCTest
import SnapshotTesting
import SnapshotTestingHEIC
import PreviewSnapshotsTesting
import SwiftUI
@testable import Nextcloud

final class NextcloudSnapshotTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let contentView = NCCapabilitiesView(capabilitiesStatus: NCCapabilitiesViewOO())
//        assertSnapshot(matching: contentView.toVC(), as: .recursiveDescription)

        NCCapabilitiesView_Previews.snapshots.assertSnapshots(as: .imageHEIC)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }
}
