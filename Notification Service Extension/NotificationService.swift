//
//  NotificationService.swift
//  Notification Service Extension
//
//  Created by Marino Faggiana on 27/07/18.
//  Copyright © 2018 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    let privateKey = CCUtility.getPushNotificationPrivateKey()
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        if let bestAttemptContent = bestAttemptContent {
            
            bestAttemptContent.title = "Nextcloud notification 🔔"
            bestAttemptContent.body = "Nextcloud notification 🔔"
            
            let message = bestAttemptContent.userInfo["subject"] as! String
            
            guard let privateKey = CCUtility.getPushNotificationPrivateKey() else {
                contentHandler(bestAttemptContent)
                return
            }
            
            guard let decryptedMessage = NCPushNotificationEncryption.sharedInstance().decryptPushNotification(message, withDevicePrivateKey: privateKey) else {
                contentHandler(bestAttemptContent)
                return
            }
            
            NSLog("[LOG] PN Decr Message, %@", decryptedMessage)
            
            let pushNotification = NCPushNotification.init(fromDecryptedString: decryptedMessage)
            if (pushNotification != nil) {
                bestAttemptContent.title = "Nextcloud notification 🔔"
                bestAttemptContent.body = pushNotification!.bodyForRemoteAlerts()
            }
            
            contentHandler(bestAttemptContent)
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            NSLog("[LOG] PN X1")
            contentHandler(bestAttemptContent)
        }
        
        NSLog("[LOG] PN X2")
    }

}
