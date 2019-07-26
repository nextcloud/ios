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

import Foundation

class NCShareNetworking: NSObject {
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    var account: String
    var activeUrl: String
    var delegate: NCShareNetworkingDelegate?
    var view: UIView?
    
    init(account: String, activeUrl: String, view: UIView?, delegate: NCShareNetworkingDelegate?) {
        self.account = account
        self.activeUrl = activeUrl
        self.view = view
        self.delegate = delegate
        
        super.init()
    }
    
    func readShare() {
        NCUtility.sharedInstance.startActivityIndicator(view: view, bottom: 0)
        OCNetworking.sharedManager()?.readShare(withAccount: account, completion: { (account, items, message, errorCode) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                let itemsOCSharedDto = items as! [OCSharedDto]
                NCManageDatabase.sharedInstance.addShare(account: self.account, activeUrl: self.activeUrl, items: itemsOCSharedDto)
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
            self.delegate?.readShareCompleted(errorCode: errorCode)
        })
    }
    
    func share(metadata: tableMetadata, password: String, permission: Int, hideDownload: Bool) {
        NCUtility.sharedInstance.startActivityIndicator(view: view, bottom: 0)
        let fileName = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, activeUrl: activeUrl)!
        OCNetworking.sharedManager()?.share(withAccount: metadata.account, fileName: fileName, password: password, permission: permission, hideDownload: hideDownload, completion: { (account, message, errorCode) in
            if errorCode == 0 {
                OCNetworking.sharedManager()?.readShare(withAccount: account, completion: { (account, items, message, errorCode) in
                    NCUtility.sharedInstance.stopActivityIndicator()
                    if errorCode == 0 {
                        let itemsOCSharedDto = items as! [OCSharedDto]
                        NCManageDatabase.sharedInstance.addShare(account: self.account, activeUrl: self.activeUrl, items: itemsOCSharedDto)
                    } else {
                        self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                    }
                    self.delegate?.shareCompleted(errorCode: errorCode)
                })
            } else {
                NCUtility.sharedInstance.stopActivityIndicator()
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
    }
    
    func unShare(idRemoteShared: Int) {
        NCUtility.sharedInstance.startActivityIndicator(view: view, bottom: 0)
        OCNetworking.sharedManager()?.unshareAccount(account, shareID: idRemoteShared, completion: { (account, message, errorCode) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                NCManageDatabase.sharedInstance.deleteTableShare(account: account!, idRemoteShared: idRemoteShared)
                self.delegate?.unShareCompleted()
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
            }
        })
    }
    
    func updateShare(idRemoteShared: Int, password: String?, permission: Int, note: String?, expirationTime: String?, hideDownload: Bool) {
        NCUtility.sharedInstance.startActivityIndicator(view: view, bottom: 0)
        OCNetworking.sharedManager()?.shareUpdateAccount(account, shareID: idRemoteShared, password: password, note:note, permission: permission, expirationTime: expirationTime, hideDownload: hideDownload, completion: { (account, message, errorCode) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                self.readShare()
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                self.delegate?.updateShareWithError(idRemoteShared: idRemoteShared)
            }
        })
    }
    
    func getUserAndGroup(searchString: String) {
        NCUtility.sharedInstance.startActivityIndicator(view: view, bottom: 0)
        OCNetworking.sharedManager()?.getUserGroup(withAccount: account, search: searchString, completion: { (account, items, message, errorCode) in
            NCUtility.sharedInstance.stopActivityIndicator()
            if errorCode == 0 {
                let itemsOCShareUser = items as! [OCShareUser]
                self.delegate?.getUserAndGroup(items: itemsOCShareUser)
            } else {
                self.appDelegate.messageNotification("_share_", description: message, visible: true, delay: TimeInterval(k_dismissAfterSecond), type: TWMessageBarMessageType.error, errorCode: errorCode)
                self.delegate?.getUserAndGroup(items: nil)
            }
        })
    }
}

protocol NCShareNetworkingDelegate {
    func readShareCompleted(errorCode: Int)
    func shareCompleted(errorCode: Int)
    func unShareCompleted()
    func updateShareWithError(idRemoteShared: Int)
    func getUserAndGroup(items: [OCShareUser]?)
}
