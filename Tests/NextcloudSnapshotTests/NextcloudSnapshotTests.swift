//
//  NextcloudSnapshotTests.swift
//  NextcloudSnapshotTests
//
//  Created by Milen on 06.06.23.
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
}
