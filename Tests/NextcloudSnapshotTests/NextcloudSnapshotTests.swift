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
    func test_HUDView() {
        HUDView_Previews.snapshots.assertSnapshots(as: .imageHEIC)
    }

    func test_CapalitiesView() {
        NCCapabilitiesView_Previews.snapshots.assertSnapshots(as: .imageHEIC)
    }

    func test_MediaView() {
        NCMediaNew_Previews.snapshots.assertSnapshots(as: .imageHEIC)
    }
}
