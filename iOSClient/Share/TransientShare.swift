// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

///
/// Transient data model for describing a share to be used in the share link user interface.
///
/// The persisted counterpart is ``tableShare``.
///
class TransientShare: Shareable {

    var shareType: Int
    var permissions: Int

    var idShare: Int = 0
    var shareWith: String = ""

    var hideDownload: Bool = false
    var password: String = ""
    var label: String = ""
    var note: String = ""
    var expirationDate: NSDate?
    var shareWithDisplayname: String = ""
    var downloadAndSync = false

    var attributes: String?

    private init(shareType: Int, metadata: tableMetadata, password: String?) {
        let capabilities = NKCapabilities.shared.getCapabilitiesBlocking(for: metadata.account)

        if metadata.e2eEncrypted, capabilities.e2EEApiVersion == NCGlobal.shared.e2eeVersionV12 {
            self.permissions = NCPermissions().permissionCreateShare
        } else {
            self.permissions = capabilities.fileSharingDefaultPermission & metadata.sharePermissionsCollaborationServices
        }

        self.shareType = shareType

        if let password = password {
            self.password = password
        }
    }

    convenience init(sharee: NKSharee, metadata: tableMetadata, password: String?) {
        self.init(shareType: sharee.shareType, metadata: metadata, password: password)
        self.shareWith = sharee.shareWith
    }

    static func shareLink(metadata: tableMetadata, password: String?) -> TransientShare {
        TransientShare(shareType: NCShareCommon().SHARE_TYPE_LINK, metadata: metadata, password: password)
    }
}
