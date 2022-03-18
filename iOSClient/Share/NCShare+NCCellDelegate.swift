//
//  NCShare+NCCellDelegate.swift
//  Nextcloud
//
//  Created by Henrik Storch on 03.01.22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//

import UIKit

// MARK: - NCCell Delegates
extension NCShare: NCShareLinkCellDelegate, NCShareUserCellDelegate {

    func copyInternalLink(sender: Any) {
        guard let metadata = self.metadata, let appDelegate = appDelegate else { return }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account) { _, metadata, errorCode, errorDescription in
            if errorCode == 0, let metadata = metadata {
                let internalLink = appDelegate.urlBase + "/index.php/f/" + metadata.fileId
                NCShareCommon.shared.copyLink(link: internalLink, viewController: self, sender: sender)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
            }
        }
    }

    func tapCopy(with tableShare: tableShare?, sender: Any) {
        guard let tableShare = tableShare else {
            return copyInternalLink(sender: sender)
        }
        NCShareCommon.shared.copyLink(link: tableShare.url, viewController: self, sender: sender)
    }

    func tapMenu(with tableShare: tableShare?, sender: Any) {
        if let tableShare = tableShare {
            self.toggleShareMenu(for: tableShare)
        } else {
            self.makeNewLinkShare()
        }
    }

    func showProfile(with tableShare: tableShare?, sender: Any) {
        guard let tableShare = tableShare else { return }
        showProfileMenu(userId: tableShare.shareWith)
    }

    func quickStatus(with tableShare: tableShare?, sender: Any) {
        guard let tableShare = tableShare,
              let metadata = metadata,
              tableShare.shareType != NCGlobal.shared.permissionDefaultFileRemoteShareNoSupportShareOption else { return }
        self.toggleUserPermissionMenu(isDirectory: metadata.directory, tableShare: tableShare)
    }
}
