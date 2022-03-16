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
        guard let metadata = self.metadata else { return }
        let isFilesSharingPublicPasswordEnforced = NCManageDatabase.shared.getCapabilitiesServerBool(account: metadata.account, elements: NCElementsJSON.shared.capabilitiesFileSharingPubPasswdEnforced, exists: false)

        if let tableShare = tableShare {
            // TODO: open share menu
            
        } else if isFilesSharingPublicPasswordEnforced {
            // create share with pw
            let alertController = UIAlertController(title: NSLocalizedString("_enforce_password_protection_", comment: ""), message: "", preferredStyle: .alert)
            alertController.addTextField { textField in
                textField.isSecureTextEntry = true
            }
            alertController.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .default) { _ in })
            let okAction = UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                let password = alertController.textFields?.first?.text
                self.networking?.createShareLink(password: password ?? "")
            }

            alertController.addAction(okAction)
            self.present(alertController, animated: true, completion: nil)
        } else {
            // create sahre without pw
            networking?.createShareLink(password: "")
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

        let quickStatusMenu = NCShareQuickStatusMenu()
        quickStatusMenu.toggleMenu(viewController: self, directory: metadata.directory, tableShare: tableShare)
    }
}
