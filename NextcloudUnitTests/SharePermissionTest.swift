//
//  SharePermissionTest.swift
//  Nextcloud
//
//  Created by Henrik Storch on 29.03.22.
//  Copyright © 2021 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

@testable import Nextcloud
import XCTest
import NextcloudKit

class SharePermissionTest: XCTestCase {
    override func setUp() {
        let json =
        """
        {"ocs":{"data":{"capabilities":{"files_sharing":{"default_permissions":31}}}}}
        """.data(using: .utf8)!
        NCManageDatabase.shared.addCapabilitiesJSon(json, account: "")
    }

    func testShareCellPermissionCell() throws {
        let share = NCTableShareOptions(sharee: NKSharee(), metadata: tableMetadata(), password: nil)
        let shareConfig = NCShareConfig(parentMetadata: tableMetadata(), share: share)

        for row in 0..<shareConfig.permissions.count {
            guard let cell = shareConfig.config(for: IndexPath(row: row, section: 0)) as? NCToggleCellConfig else {
                XCTFail("Invalid share permission cell")
                continue
            }
            XCTAssertFalse(cell.isOn(for: share))
        }

        let meta = tableMetadata()
        meta.sharePermissionsCollaborationServices = 31
        let fullShare = NCTableShareOptions(sharee: NKSharee(), metadata: meta, password: nil)
        let shareFullConfig = NCShareConfig(parentMetadata: meta, share: fullShare)

        for row in 0..<shareFullConfig.permissions.count {
            guard let cell = shareConfig.config(for: IndexPath(row: row, section: 0)) as? NCToggleCellConfig else {
                XCTFail("Invalid share permission cell")
                continue
            }
            XCTAssertTrue(cell.isOn(for: fullShare))
        }
    }

    func testSharePermission() throws {
        XCTAssertTrue(NCLinkPermission.allowEdit.hasResharePermission(for: 15))
        XCTAssertTrue(NCLinkPermission.allowEdit.hasResharePermission(for: 11))
        XCTAssertTrue(NCLinkPermission.allowEdit.hasResharePermission(for: 7))
        XCTAssertFalse(NCLinkPermission.allowEdit.hasResharePermission(for: 13))
        XCTAssertFalse(NCLinkPermission.allowEdit.hasResharePermission(for: 1))

        XCTAssertTrue(NCLinkPermission.viewOnly.hasResharePermission(for: 25))
        XCTAssertTrue(NCLinkPermission.viewOnly.hasResharePermission(for: 17))
        XCTAssertFalse(NCLinkPermission.viewOnly.hasResharePermission(for: 12))
        XCTAssertFalse(NCLinkPermission.viewOnly.hasResharePermission(for: 2))

        XCTAssertTrue(NCLinkPermission.fileDrop.hasResharePermission(for: 4))
        XCTAssertFalse(NCLinkPermission.fileDrop.hasResharePermission(for: 27))

        XCTAssertTrue(NCUserPermission.create.hasResharePermission(for: 4))
        XCTAssertFalse(NCUserPermission.create.hasResharePermission(for: 27))

        XCTAssertTrue(NCUserPermission.edit.hasResharePermission(for: 2))
        XCTAssertFalse(NCUserPermission.edit.hasResharePermission(for: 29))

        XCTAssertTrue(NCUserPermission.reshare.hasResharePermission(for: 16))
        XCTAssertFalse(NCUserPermission.reshare.hasResharePermission(for: 15))
    }

    func testFileShare() throws {
        let meta = tableMetadata()
        meta.directory = false
        let share = NCTableShareOptions.shareLink(metadata: meta, password: nil)
        let fileConfig = NCShareConfig(parentMetadata: meta, share: share)
        XCTAssertEqual(fileConfig.advanced, NCShareDetails.forLink)
        XCTAssertEqual(fileConfig.permissions as? [NCLinkPermission], NCLinkPermission.forFile)

        meta.directory = true
        let folderConfig = NCShareConfig(parentMetadata: meta, share: share)
        XCTAssertEqual(folderConfig.advanced, NCShareDetails.forLink)
        XCTAssertEqual(folderConfig.permissions as? [NCLinkPermission], NCLinkPermission.forDirectory)
    }

    func testUserShare() throws {
        let meta = tableMetadata()
        meta.directory = false
        let sharee = NKSharee()
        let share = NCTableShareOptions(sharee: sharee, metadata: meta, password: nil)
        let fileConfig = NCShareConfig(parentMetadata: meta, share: share)
        XCTAssertEqual(fileConfig.advanced, NCShareDetails.forUser)
        XCTAssertEqual(fileConfig.permissions as? [NCUserPermission], NCUserPermission.forFile)

        meta.directory = true
        let folderConfig = NCShareConfig(parentMetadata: meta, share: share)
        XCTAssertEqual(folderConfig.advanced, NCShareDetails.forUser)
        XCTAssertEqual(folderConfig.permissions as? [NCUserPermission], NCUserPermission.forDirectory)
    }

    func testResharePermission() throws {
        let meta = tableMetadata()
        let permissionReadShare = NCGlobal.shared.permissionShareShare + NCGlobal.shared.permissionReadShare
        meta.sharePermissionsCollaborationServices = permissionReadShare
        meta.directory = false
        let share = NCTableShareOptions.shareLink(metadata: meta, password: nil)
        let fileConfig = NCShareConfig(parentMetadata: meta, share: share)
        XCTAssertEqual(fileConfig.resharePermission, meta.sharePermissionsCollaborationServices)
        XCTAssertEqual(fileConfig.advanced, NCShareDetails.forLink)
        XCTAssertEqual(fileConfig.permissions as? [NCLinkPermission], NCLinkPermission.forFile)

        meta.directory = true
        let sharee = NKSharee()
        let folderShare = NCTableShareOptions(sharee: sharee, metadata: meta, password: nil)
        let folderConfig = NCShareConfig(parentMetadata: meta, share: folderShare)
        XCTAssertEqual(folderConfig.resharePermission, meta.sharePermissionsCollaborationServices)
        XCTAssertEqual(folderConfig.advanced, NCShareDetails.forUser)
        XCTAssertEqual(folderConfig.permissions as? [NCUserPermission], NCUserPermission.forDirectory)
    }
}
