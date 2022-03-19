//
//  NCShare+Helper.swift
//  Nextcloud
//
//  Created by Henrik Storch on 19.03.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import UIKit
import NCCommunication

extension tableShare: TableShareable { }
protocol TableShareable: AnyObject {
    var shareType: Int { get set }
    var permissions: Int { get set }

    var account: String { get }

    var idShare: Int { get set }
    var shareWith: String { get set }
//    var publicUpload: Bool? = false
    var hideDownload: Bool { get set }
    var password: String { get set }
    var label: String { get set }
    var note: String { get set }
    var expirationDate: NSDate? { get set }
    var shareWithDisplayname: String { get set }
}

extension TableShareable {
    var expDateString: String? {
        guard let date = expirationDate else { return nil }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        return dateFormatter.string(from: date as Date)
    }
}

class TableShareOptions: TableShareable {
    var shareType: Int
    var permissions: Int

    let account: String

    var idShare: Int = 0
    var shareWith: String = ""
//    var publicUpload: Bool? = false
    var hideDownload: Bool = false
    var password: String = ""
    var label: String = ""
    var note: String = ""
    var expirationDate: NSDate?
    var shareWithDisplayname: String = ""

    private init(shareType: Int, metadata: tableMetadata, password: String? = nil) {
        self.permissions = NCManageDatabase.shared.getCapabilitiesServerInt(account: metadata.account, elements: ["ocs", "data", "capabilities", "files_sharing", "default_permissions"]) & metadata.sharePermissionsCollaborationServices
        self.shareType = shareType
        self.account = metadata.account
        if let password = password {
            self.password = password
        }
    }

    convenience init(sharee: NCCommunicationSharee, metadata: tableMetadata) {
        self.init(shareType: sharee.shareType, metadata: metadata)
        self.shareWith = sharee.shareWith
    }

    static func shareLink(metadata: tableMetadata, password: String?) -> TableShareOptions {
        return TableShareOptions(shareType: NCShareCommon.shared.SHARE_TYPE_LINK, metadata: metadata, password: password)
    }
}

protocol NCShareDetail {
    var share: TableShareable! { get }
}

extension NCShareDetail where Self: UIViewController {
    func setNavigationTitle() {
        title = NSLocalizedString("_share_", comment: "") + "  – "
        if share.shareType == NCShareCommon.shared.SHARE_TYPE_LINK {
            title! += share.label.isEmpty ? NSLocalizedString("_share_link_", comment: "") : share.label
        } else {
            title! += share.shareWithDisplayname.isEmpty ? share.shareWith : share.shareWithDisplayname
        }
    }
}
