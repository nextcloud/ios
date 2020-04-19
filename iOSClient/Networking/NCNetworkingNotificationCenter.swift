//
//  NCNetworkingNotificationCenter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/04/2020.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

import Foundation

@objc class NCNetworkingNotificationCenter: NSObject {
    @objc public static let shared: NCNetworkingNotificationCenter = {
        let instance = NCNetworkingNotificationCenter()
        
        NotificationCenter.default.addObserver(instance, selector: #selector(uploadFileStart(_:)), name: NSNotification.Name(rawValue: k_notificationCenter_uploadFileStart), object: nil)
        
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func uploadFileStart(_ notification: NSNotification) {
        
        if let userInfo = notification.userInfo as NSDictionary? {
            if let ocId = userInfo["ocId"] as? String, let serverUrl = userInfo["serverUrl"] as? String, let _ = userInfo["uploadTask"] as? URLSessionUploadTask {
                
                NCMainCommon.sharedInstance.reloadDatasource(ServerUrl: serverUrl, ocId: ocId, action: Int32(k_action_MOD))
                appDelegate.updateApplicationIconBadgeNumber()
            }
        }
    }
}

