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
    
    var activeUrl: String
    var delegate: NCShareNetworkingDelegate?
    var view: UIView
    var metadata: tableMetadata
    
    init(metadata: tableMetadata, activeUrl: String, view: UIView, delegate: NCShareNetworkingDelegate?) {
        self.metadata = metadata
        self.activeUrl = activeUrl
        self.view = view
        self.delegate = delegate
        
        super.init()
    }
    
    func readShare() {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: activeUrl)!
        NCCommunication.shared.readShares(path: filenamePath) { (account, shares, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
             if errorCode == 0 && shares != nil {
                NCManageDatabase.sharedInstance.addShare(account: self.metadata.account, activeUrl: self.activeUrl, shares: shares!)
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
            }
            self.delegate?.readShareCompleted()
        }
    }
    
    func createShareLink(password: String?) {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: activeUrl)!
        NCCommunication.shared.createShareLink(path: filenamePath, password: password) { (account, share, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(account: self.metadata.account, activeUrl: self.activeUrl, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else if errorCode != 0 {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
            }
            self.delegate?.shareCompleted()
        }
    }
    
    func createShare(name: String, shareType: Int, metadata: tableMetadata) {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        let filenamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: activeUrl)!
        var permission: Int = 1
        if metadata.directory { permission = Int(k_max_folder_share_permission) } else { permission = Int(k_max_file_share_permission) }
        NCCommunication.shared.createShare(path: filenamePath, shareType: shareType, shareWith: name, permissions: permission) { (account, share, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(account: self.metadata.account, activeUrl: self.activeUrl, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
            }
        }
    }
    
    func unShare(idShare: Int) {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        NCCommunication.shared.deleteShare(idShare: idShare) { (account, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                NCManageDatabase.sharedInstance.deleteTableShare(account: account, idShare: idShare)
                self.delegate?.unShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
            }
        }
    }
    
    func updateShare(idShare: Int, password: String?, permission: Int, note: String?, expirationDate: String?, hideDownload: Bool) {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        NCCommunication.shared.updateShare(idShare: idShare, password: password, expireDate: expirationDate, permissions: permission, note: note, hideDownload: hideDownload) { (account, share, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 && share != nil {
                NCManageDatabase.sharedInstance.addShare(account: self.metadata.account, activeUrl: self.activeUrl, shares: [share!])
                self.appDelegate.shares = NCManageDatabase.sharedInstance.getTableShares(account: self.metadata.account)
                self.delegate?.readShareCompleted()
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
                self.delegate?.updateShareWithError(idShare: idShare)
            }
        }
    }
    
    func getUserAndGroup(searchString: String) {
        NCUtility.sharedInstance.startActivityIndicator(view: view)
        NCCommunication.shared.searchSharees(search: searchString) { (account, sharees, errorCode, errorDescription) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                self.delegate?.getUserAndGroup(sharees: sharees)
            } else {
                NCContentPresenter.shared.messageNotification("_share_", description: errorDescription, delay: TimeInterval(k_dismissAfterSecond), type: NCContentPresenter.messageType.error, errorCode: 0)
                self.delegate?.getUserAndGroup(sharees: nil)
            }
        }
    }
}

protocol NCShareNetworkingDelegate {
    func readShareCompleted()
    func shareCompleted()
    func unShareCompleted()
    func updateShareWithError(idShare: Int)
    func getUserAndGroup(sharees: [NCCommunicationSharee]?)
}
