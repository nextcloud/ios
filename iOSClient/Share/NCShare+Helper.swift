//
//  NCShare+Helper.swift
//  Nextcloud
//
//  Created by Henrik Storch on 19.03.22.
//  Copyright © 2022 Henrik Storch. All rights reserved.
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

import UIKit
import NextcloudKit

extension tableShare: NCTableShareable { }
extension NKShare: NCTableShareable { }

protocol NCTableShareable: AnyObject {
    var shareType: Int { get set }
    var permissions: Int { get set }

    var idShare: Int { get set }
    var shareWith: String { get set }

    var hideDownload: Bool { get set }
    var password: String { get set }
    var label: String { get set }
    var note: String { get set }
    var expirationDate: NSDate? { get set }
    var shareWithDisplayname: String { get set }
}

extension NCTableShareable {
    var expDateString: String? {
        guard let date = expirationDate else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return dateFormatter.string(from: date as Date)
    }

    func hasChanges(comparedTo other: NCTableShareable) -> Bool {
        return other.shareType != shareType
        || other.permissions != permissions
        || other.hideDownload != hideDownload
        || other.password != password
        || other.label != label
        || other.note != note
        || other.expirationDate != expirationDate
    }
}

class NCTableShareOptions: NCTableShareable {
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

    private init(shareType: Int, metadata: tableMetadata, password: String?) {
        if metadata.e2eEncrypted {
            self.permissions = NCGlobal.shared.permissionCreateShare
        } else {
            self.permissions = NCGlobal.shared.capabilityFileSharingDefaultPermission & metadata.sharePermissionsCollaborationServices
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

    static func shareLink(metadata: tableMetadata, password: String?) -> NCTableShareOptions {
        return NCTableShareOptions(shareType: NCShareCommon.shared.SHARE_TYPE_LINK, metadata: metadata, password: password)
    }
}

protocol NCShareDetail {
    var share: NCTableShareable! { get }
}

extension NCShareDetail where Self: UIViewController {
    func setNavigationTitle() {
        title = NSLocalizedString("_share_", comment: "") + " – "
        if share.shareType == NCShareCommon.shared.SHARE_TYPE_LINK {
            title! += share.label.isEmpty ? NSLocalizedString("_share_link_", comment: "") : share.label
        } else {
            title! += share.shareWithDisplayname.isEmpty ? share.shareWith : share.shareWithDisplayname
        }
    }
}
