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
import os
import NextcloudKit

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    var request: UNNotificationRequest?
    private let deliveryLock = OSAllocatedUnfairLock()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        self.request = request
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        NextcloudKit.configureLogger(logLevel: .verbose)

        guard let bestAttemptContent else { return }

        bestAttemptContent.title = ""
        bestAttemptContent.body = "Nextcloud notification"

        var matchedAccount: tableAccount?
        var payload: [String: AnyObject]?

        do {
            if let message = bestAttemptContent.userInfo["subject"] as? String {
                for tableAccount in NCManageDatabase.shared.getAllTableAccount() {
                    guard let privateKey = NCPreferences().getPushNotificationPrivateKey(account: tableAccount.account) else {
                        bestAttemptContent.body = "Error retrieving private key for \(tableAccount.account)"
                        continue
                    }

                    let prefixData = Data(privateKey.prefix(8))
                    let prefixBase64 = prefixData.base64EncodedString()
                    nkLog(debug: "🔑 Loaded private key for \(tableAccount.account): prefix(Base64)=\(prefixBase64)")

                    guard let decryptedMessage = NCPushNotificationEncryption.shared().decryptPushNotification(message, withDevicePrivateKey: privateKey) else {
                        bestAttemptContent.body = "Error decrypting notification for \(tableAccount.account)"
                        continue
                    }
                    guard let data = decryptedMessage.data(using: .utf8) else {
                        bestAttemptContent.body = "Error decrypting UTF8 notification data for \(tableAccount.account)"
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

                        matchedAccount = tableAccount
                        payload = json
                    } else {
                        bestAttemptContent.body = "Error with notification JSON for \(tableAccount.account)"
                    }
                    break
                }
            }
        } catch let error as NSError {
            nkLog(error: "Failed : \(error.localizedDescription)")
        }

        guard let tblAccount = matchedAccount,
              let nid = payload?["nid"] as? Int,
              payload?["delete"] as? Bool != true,
              payload?["delete-all"] as? Bool != true else {
            deliver()
            return
        }

        // NextcloudKit Session
        NextcloudKit.shared.setup(groupIdentifier: NCBrandOptions.shared.capabilitiesGroup, delegate: NCNetworking.shared)
        NextcloudKit.shared.appendSession(account: tblAccount.account,
                                          urlBase: tblAccount.urlBase,
                                          user: tblAccount.user,
                                          userId: tblAccount.userId,
                                          password: NCPreferences().getPassword(account: tblAccount.account),
                                          userAgent: userAgent,
                                          groupIdentifier: NCBrandOptions.shared.capabilitiesGroup)

        Task {
            let results = await NextcloudKit.shared.getNotificationsAsync(idNotification: nid,
                                                                          account: tblAccount.account,
                                                                          options: NKRequestOptions(timeout: 20))

            if results.error == .success, let notification = results.notifications?.first {
                bestAttemptContent.title = notification.message.isEmpty ? NCBrandOptions.shared.brand : notification.subject
                bestAttemptContent.body = notification.message.isEmpty ? notification.subject : notification.message
            }

            deliver()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        deliver()
    }

    private func deliver() {
        let handler = deliveryLock.withLock {
            let handler = contentHandler
            contentHandler = nil
            return handler
        }

        if let handler, let bestAttemptContent {
            handler(bestAttemptContent)
        }
    }
}
