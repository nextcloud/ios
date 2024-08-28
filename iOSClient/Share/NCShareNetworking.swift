//
//  NCShareNetworking.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

import UIKit
import NextcloudKit

class NCShareNetworking: NSObject {
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    weak var delegate: NCShareNetworkingDelegate?
    var view: UIView
    var metadata: tableMetadata

    init(metadata: tableMetadata, view: UIView, delegate: NCShareNetworkingDelegate?) {
        self.metadata = metadata
        self.view = view
        self.delegate = delegate

        super.init()
    }

    func readShare(showLoadingIndicator: Bool) {

        if showLoadingIndicator {
            NCActivityIndicator.shared.start(backgroundView: view)
        }

        let filenamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        let parameter = NKShareParameter(path: filenamePath)

        NextcloudKit.shared.readShares(parameters: parameter, account: metadata.account) { account, shares, _, error in
            if error == .success, let shares = shares {
                NCManageDatabase.shared.deleteTableShare(account: account, path: "/" + filenamePath)
                let home = self.utilityFileSystem.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home: home, shares: shares)
                NextcloudKit.shared.getGroupfolders(account: account) { account, results, _, error in
                    if showLoadingIndicator {
                        NCActivityIndicator.shared.stop()
                    }
                    if error == .success, let groupfolders = results {
                        NCManageDatabase.shared.addGroupfolders(account: account, groupfolders: groupfolders)
                    }
                    self.delegate?.readShareCompleted()
                }
            } else {
                if showLoadingIndicator {
                    NCActivityIndicator.shared.stop()
                }
                NCContentPresenter().showError(error: error)
                self.delegate?.readShareCompleted()
            }
        }
    }

    func createShare(option: NCTableShareable) {
        // NOTE: Permissions don't work for creating with file drop!
        // https://github.com/nextcloud/server/issues/17504

        // NOTE: Can't save label and expirationDate in the same request.
        // Library update needed:
        // https://github.com/nextcloud/ios-communication-library/pull/104

        NCActivityIndicator.shared.start(backgroundView: view)
        let filenamePath = utilityFileSystem.getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)

        NextcloudKit.shared.createShare(path: filenamePath, shareType: option.shareType, shareWith: option.shareWith, password: option.password, note: option.note, permissions: option.permissions, attributes: option.attributes, account: metadata.account) { _, share, _, error in
            NCActivityIndicator.shared.stop()
            if error == .success, let share = share {
                option.idShare = share.idShare
                let home = self.utilityFileSystem.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home: home, shares: [share])
                if option.hasChanges(comparedTo: share) {
                    self.updateShare(option: option)
                }
            } else {
                NCContentPresenter().showError(error: error)
            }
            self.delegate?.shareCompleted()
        }
    }

    func unShare(idShare: Int) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.deleteShare(idShare: idShare, account: metadata.account) { account, error in
            NCActivityIndicator.shared.stop()
            if error == .success {
                NCManageDatabase.shared.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }

    func updateShare(option: NCTableShareable) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.updateShare(idShare: option.idShare, password: option.password, expireDate: option.expDateString, permissions: option.permissions, note: option.note, label: option.label, hideDownload: option.hideDownload, attributes: option.attributes, account: metadata.account) { _, share, _, error in
            NCActivityIndicator.shared.stop()
            if error == .success, let share = share {
                let home = self.utilityFileSystem.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home: home, shares: [share])
                self.delegate?.readShareCompleted()
            } else {
                NCContentPresenter().showError(error: error)
                self.delegate?.updateShareWithError(idShare: option.idShare)
            }
        }
    }

    func getSharees(searchString: String) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.searchSharees(search: searchString, account: metadata.account) { _, sharees, _, error in
            NCActivityIndicator.shared.stop()
            if error == .success {
                self.delegate?.getSharees(sharees: sharees)
            } else {
                NCContentPresenter().showError(error: error)
                self.delegate?.getSharees(sharees: nil)
            }
        }
    }
}

protocol NCShareNetworkingDelegate: AnyObject {
    func readShareCompleted()
    func shareCompleted()
    func unShareCompleted()
    func updateShareWithError(idShare: Int)
    func getSharees(sharees: [NKSharee]?)
}
