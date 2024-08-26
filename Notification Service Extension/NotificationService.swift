//
//  NotificationService.swift
//  Notification Service Extension
//
//  Created by Ivan Sein on 30.01.20.
//  Author Ivan Sein <ivan@nextcloud.com>
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
import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        if let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.title = ""
            bestAttemptContent.body = "Nextcloud notification"
            do {
                if let message = bestAttemptContent.userInfo["subject"] as? String {
                    for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
                        guard let privateKey = NCKeychain().getPushNotificationPrivateKey(account: tableAccount.account),
                              let decryptedMessage = NCPushNotificationEncryption.shared().decryptPushNotification(message, withDevicePrivateKey: privateKey),
                              let data = decryptedMessage.data(using: .utf8) else {
                            continue
                        }
                        if var json = try JSONSerialization.jsonObject(with: data) as? [String: AnyObject],
                           let subject = json["subject"] as? String {
                            bestAttemptContent.body = subject
                            if let pref = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) {
                                json["account"] = tableAccount.account as AnyObject
                                pref.set(json, forKey: "NOTIFICATION_DATA")
                                pref.synchronize()
                            }
                        }
                    }
                }
            } catch let error as NSError {
                print("Failed : \(error.localizedDescription)")
            }

            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            bestAttemptContent.title = ""
            bestAttemptContent.body = "Nextcloud notification"
            contentHandler(bestAttemptContent)
        }
    }

}
