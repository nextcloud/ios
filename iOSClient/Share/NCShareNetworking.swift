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
import NCCommunication

class NCShareNetworking: NSObject {

    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    var urlBase: String
    weak var delegate: NCShareNetworkingDelegate?
    var view: UIView
    var metadata: tableMetadata

    init(metadata: tableMetadata, urlBase: String, view: UIView, delegate: NCShareNetworkingDelegate?) {
        self.metadata = metadata
        self.urlBase = urlBase
        self.view = view
        self.delegate = delegate

        super.init()
    }

    func readShare(showLoadingIndicator: Bool) {
        if showLoadingIndicator {
            NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        }

        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        let parameter = NCCShareParameter(path: filenamePath)
        NCCommunication.shared.readShares(parameters: parameter) { account, shares, errorCode, errorDescription in
            if showLoadingIndicator {
                NCUtility.shared.stopActivityIndicator()
            }

             if errorCode == 0 && shares != nil {
                NCManageDatabase.shared.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: shares!)
                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
            self.delegate?.readShareCompleted()
        }
    }

    func createShareLink(password: String?) {
        NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        NCCommunication.shared.createShareLink(path: filenamePath, password: password) { account, share, errorCode, errorDescription in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.shared.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: self.metadata.account)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
            self.delegate?.shareCompleted()
        }
    }
    
    func createShare(shareWith: String, shareType: Int, password: String?, metadata: tableMetadata) {
        NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        var permission: Int = NCManageDatabase.shared.getCapabilitiesServerInt(account: metadata.account, elements: ["ocs", "data", "capabilities", "files_sharing", "default_permissions"])
        if permission <= 0 {
            permission = metadata.directory ? NCGlobal.shared.permissionMaxFolderShare : NCGlobal.shared.permissionMaxFileShare
        }

        NCCommunication.shared.createShare(path: filenamePath, shareType: shareType, shareWith: shareWith, password: password, permissions: permission) { (account, share, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.shared.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
            self.delegate?.shareCompleted()
        }
    }

    func unShare(idShare: Int) {
        NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        NCCommunication.shared.deleteShare(idShare: idShare) { account, errorCode, errorDescription in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 {
                NCManageDatabase.shared.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
            }
        }
    }

    func updateShare(idShare: Int, password: String?, permissions: Int, note: String?, label: String?, expirationDate: String?, hideDownload: Bool) {
        NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        NCCommunication.shared.updateShare(idShare: idShare, password: password, expireDate: expirationDate, permissions: permissions, note: note, label: label, hideDownload: hideDownload) { account, share, errorCode, errorDescription in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.shared.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.shared.getTableShares(account: self.metadata.account)
                self.delegate?.readShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
                self.delegate?.updateShareWithError(idShare: idShare)
            }
        }
    }

    func getSharees(searchString: String) {
        NCUtility.shared.startActivityIndicator(backgroundView: view, blurEffect: false)
        NCCommunication.shared.searchSharees(search: searchString) { _, sharees, errorCode, errorDescription in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 {
                self.delegate?.getSharees(sharees: sharees)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: NCGlobal.shared.errorInternalError)
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
    func getSharees(sharees: [NCCommunicationSharee]?)
}
