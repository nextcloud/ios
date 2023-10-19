//
//  NCOperationQueue.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 03/06/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
import Queuer
import NextcloudKit
import JGProgressHUD

@objc class NCOperationQueue: NSObject {
    @objc public static let shared: NCOperationQueue = {
        let instance = NCOperationQueue()
        return instance
    }()

    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!



    // MARK: - Download Avatar

    func downloadAvatar(user: String, dispalyName: String?, fileName: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {

        let fileNameLocalPath = String(CCUtility.getDirectoryUserData()) + "/" + fileName

        if let image = NCManageDatabase.shared.getImageAvatarLoaded(fileName: fileName) {
            cellImageView?.image = image
            cell.fileAvatarImageView?.image = image
            return
        }

        if let account = NCManageDatabase.shared.getActiveAccount() {
            cellImageView?.image = NCUtility.shared.loadUserImage(
                for: user,
                   displayName: dispalyName,
                   userBaseUrl: account)
        }

        for case let operation as NCOperationDownloadAvatar in appDelegate.downloadAvatarQueue.operations where operation.fileName == fileName { return }
        appDelegate.downloadAvatarQueue.addOperation(NCOperationDownloadAvatar(user: user, fileName: fileName, fileNameLocalPath: fileNameLocalPath, cell: cell, view: view, cellImageView: cellImageView))
    }
}

// MARK: -

class NCOperationDownloadAvatar: ConcurrentOperation {

    var user: String
    var fileName: String
    var etag: String?
    var fileNameLocalPath: String
    var cell: NCCellProtocol!
    var view: UIView?
    var cellImageView: UIImageView?

    init(user: String, fileName: String, fileNameLocalPath: String, cell: NCCellProtocol, view: UIView?, cellImageView: UIImageView?) {
        self.user = user
        self.fileName = fileName
        self.fileNameLocalPath = fileNameLocalPath
        self.cell = cell
        self.view = view
        self.etag = NCManageDatabase.shared.getTableAvatar(fileName: fileName)?.etag
        self.cellImageView = cellImageView
    }

    override func start() {

        guard !isCancelled else { return self.finish() }

        NextcloudKit.shared.downloadAvatar(user: user,
                                           fileNameLocalPath: fileNameLocalPath,
                                           sizeImage: NCGlobal.shared.avatarSize,
                                           avatarSizeRounded: NCGlobal.shared.avatarSizeRounded,
                                           etag: self.etag,
                                           options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)) { _, imageAvatar, _, etag, error in

            if error == .success, let imageAvatar = imageAvatar, let etag = etag {
                NCManageDatabase.shared.addAvatar(fileName: self.fileName, etag: etag)
                DispatchQueue.main.async {
                    if self.user == self.cell.fileUser, let avatarImageView = self.cellImageView {
                        UIView.transition(with: avatarImageView,
                                          duration: 0.75,
                                          options: .transitionCrossDissolve,
                                          animations: { avatarImageView.image = imageAvatar },
                                          completion: nil)
                    } else {
                        if self.view is UICollectionView {
                            (self.view as? UICollectionView)?.reloadData()
                        } else if self.view is UITableView {
                            (self.view as? UITableView)?.reloadData()
                        }
                    }
                }
            } else if error.errorCode == NCGlobal.shared.errorNotModified {
                NCManageDatabase.shared.setAvatarLoaded(fileName: self.fileName)
            }
            self.finish()
        }
    }
}

