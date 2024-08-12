//
//  NCShare+NCCellDelegate.swift
//  Nextcloud
//
//  Created by Henrik Storch on 03.01.22.
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

// MARK: - NCCell Delegates
extension NCShare: NCShareLinkCellDelegate, NCShareUserCellDelegate {

    func copyInternalLink(sender: Any) {
        guard let metadata = self.metadata else { return }

        let serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
        NCNetworking.shared.readFile(serverUrlFileName: serverUrlFileName, account: metadata.account) { _, metadata, error in
            if error == .success, let metadata = metadata {
                let internalLink = metadata.urlBase + "/index.php/f/" + metadata.fileId
                self.shareCommon.copyLink(link: internalLink, viewController: self, sender: sender)
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func tapCopy(with tableShare: tableShare?, sender: Any) {
        guard let tableShare = tableShare else {
            return copyInternalLink(sender: sender)
        }
        shareCommon.copyLink(link: tableShare.url, viewController: self, sender: sender)
    }

    func tapMenu(with tableShare: tableShare?, sender: Any) {
        if let tableShare = tableShare {
            self.toggleShareMenu(for: tableShare)
        } else {
            self.makeNewLinkShare()
        }
    }

    func showProfile(with tableShare: tableShare?, sender: Any) {
        guard let tableShare else { return }
        showProfileMenu(userId: tableShare.shareWith, session: session)
    }

    func quickStatus(with tableShare: tableShare?, sender: Any) {
        guard let tableShare,
              let metadata,
              tableShare.shareType != NCPermissions().permissionDefaultFileRemoteShareNoSupportShareOption else { return }
        self.toggleUserPermissionMenu(isDirectory: metadata.directory, tableShare: tableShare)
    }
}
