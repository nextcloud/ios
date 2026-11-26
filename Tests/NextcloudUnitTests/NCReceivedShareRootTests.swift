// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Received share root detection")
struct NCReceivedShareRootTests {
    @Test("A shared item in one of the user's own folders is the top of a received share")
    func receivedShareRoot() {
        #expect(NCMetadataPermissions.isReceivedShareRoot(permissions: "SRGDNVCK", parentPermissions: "RGDNVCK"))
    }

    @Test("An item inside a received share is not its top")
    func itemInsideReceivedShare() {
        #expect(!NCMetadataPermissions.isReceivedShareRoot(permissions: "SRGDNVW", parentPermissions: "SRGDNVCK"))
    }

    @Test("The user's own items are not received shares")
    func ownItem() {
        #expect(!NCMetadataPermissions.isReceivedShareRoot(permissions: "RGDNVCK", parentPermissions: "RGDNVCK"))
    }

    @Test("Without the parent folder the item is not treated as a received share")
    func unknownParent() {
        #expect(!NCMetadataPermissions.isReceivedShareRoot(permissions: "SRGDNVCK", parentPermissions: nil))
    }
}
