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

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

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

        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
        let parameter = NKShareParameter(path: filenamePath)

        NextcloudKit.shared.nkCommonInstance.writeLog("[TEST] READSHARES")
        
        NextcloudKit.shared.readShares(parameters: parameter) { account, shares, data, error in
            if showLoadingIndicator {
                NCActivityIndicator.shared.stop()
            }

            if error == .success, let shares = shares {
                let home = NCUtilityFileSystem.shared.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home:home, shares: shares)
            } else {
                NCContentPresenter.shared.showError(error: error)
            }
            self.delegate?.readShareCompleted()
        }
    }
    
    func createShare(option: NCTableShareable) {
        // NOTE: Permissions don't work for creating with file drop!
        // https://github.com/nextcloud/server/issues/17504

        // NOTE: Can't save label, expirationDate, and note in same request.
        // Library update needed:
        // https://github.com/nextcloud/ios-communication-library/pull/104

        NCActivityIndicator.shared.start(backgroundView: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!

        NextcloudKit.shared.createShare(path: filenamePath, shareType: option.shareType, shareWith: option.shareWith, password: option.password, permissions: option.permissions) { (account, share, data, error) in
            NCActivityIndicator.shared.stop()
            if error == .success, let share = share {
                option.idShare = share.idShare
                let home = NCUtilityFileSystem.shared.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home: home, shares: [share])
                if option.hasChanges(comparedTo: share) {
                    self.updateShare(option: option)
                }
            } else {
                NCContentPresenter.shared.showError(error: error)
            }
            self.delegate?.shareCompleted()
        }
    }

    func unShare(idShare: Int) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.deleteShare(idShare: idShare) { account, error in
            NCActivityIndicator.shared.stop()
            if error == .success {
                NCManageDatabase.shared.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()
            } else {
                NCContentPresenter.shared.showError(error: error)
            }
        }
    }

    func updateShare(option: NCTableShareable) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.updateShare(idShare: option.idShare, password: option.password, expireDate: option.expDateString, permissions: option.permissions, note: option.note, label: option.label, hideDownload: option.hideDownload) { account, share, data, error in
            NCActivityIndicator.shared.stop()
            if error == .success, let share = share {
                let home = NCUtilityFileSystem.shared.getHomeServer(urlBase: self.metadata.urlBase, userId: self.metadata.userId)
                NCManageDatabase.shared.addShare(account: self.metadata.account, home: home, shares: [share])
                self.delegate?.readShareCompleted()
            } else {
                NCContentPresenter.shared.showError(error: error)
                self.delegate?.updateShareWithError(idShare: option.idShare)
            }
        }
    }

    func getSharees(searchString: String) {
        NCActivityIndicator.shared.start(backgroundView: view)
        NextcloudKit.shared.searchSharees(search: searchString) { _, sharees, data, error in
            NCActivityIndicator.shared.stop()
            if error == .success {
                self.delegate?.getSharees(sharees: sharees)
            } else {
                NCContentPresenter.shared.showError(error: error)
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
