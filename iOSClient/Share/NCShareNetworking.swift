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

 //NotificationCenter.default.postOnMainThread(name: k_notificationCenter_reloadDataSource, userInfo: ["serverUrl":self.metadata.serverUrl])

import Foundation
import NCCommunication

class NCShareNetworking: NSObject {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var urlBase: String
    var delegate: NCShareNetworkingDelegate?
    var view: UIView
    var metadata: tableMetadata
    
    init(metadata: tableMetadata, urlBase: String, view: UIView, delegate: NCShareNetworkingDelegate?) {
        self.metadata = metadata
        self.urlBase = urlBase
        self.view = view
        self.delegate = delegate
        
        super.init()
    }
    
    func readShare() {
        NCUtility.shared.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        NCCommunication.shared.readShares(path: filenamePath) { (account, shares, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
             if errorCode == 0 && shares != nil {
                NCManageDatabase.sharedInstance.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: shares!)
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
            }
            self.delegate?.readShareCompleted()
        }
    }
    
    func createShareLink(password: String?) {
        NCUtility.shared.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        NCCommunication.shared.createShareLink(path: filenamePath, password: password) { (account, share, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
            }
            self.delegate?.shareCompleted()
        }
    }
    
    func createShare(shareWith: String, shareType: Int, metadata: tableMetadata) {
        NCUtility.shared.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: urlBase, account: metadata.account)!
        var permission: Int = 1
        if metadata.directory { permission = Int(k_max_folder_share_permission) } else { permission = Int(k_max_file_share_permission) }
        NCCommunication.shared.createShare(path: filenamePath, shareType: shareType, shareWith: shareWith, permissions: permission) { (account, share, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
            }
            self.delegate?.shareCompleted()
        }
    }
    
    func unShare(idShare: Int) {
        NCUtility.shared.startActivityIndicator(view: view)
        NCCommunication.shared.deleteShare(idShare: idShare) { (account, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 {
                NCManageDatabase.sharedInstance.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
            }
        }
    }
    
    func updateShare(idShare: Int, password: String?, permission: Int, note: String?, expirationDate: String?, hideDownload: Bool) {
        NCUtility.shared.startActivityIndicator(view: view)
        NCCommunication.shared.updateShare(idShare: idShare, password: password, expireDate: expirationDate, permissions: permission, note: note, hideDownload: hideDownload) { (account, share, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(urlBase: self.urlBase, account: self.metadata.account, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
                self.delegate?.readShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
                self.delegate?.updateShareWithError(idShare: idShare)
            }
        }
    }
    
    func getSharees(searchString: String) {
        NCUtility.shared.startActivityIndicator(view: view)
        NCCommunication.shared.searchSharees(search: searchString) { (account, sharees, errorCode, errorDescription) in
            NCUtility.shared.stopActivityIndicator()
            if errorCode == 0 {
                self.delegate?.getSharees(sharees: sharees)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: Int(k_CCErrorInternalError), forced: true)
                self.delegate?.getSharees(sharees: nil)
            }
        }
    }
}

protocol NCShareNetworkingDelegate {
    func readShareCompleted()
    func shareCompleted()
    func unShareCompleted()
    func updateShareWithError(idShare: Int)
    func getSharees(sharees: [NCCommunicationSharee]?)
}
