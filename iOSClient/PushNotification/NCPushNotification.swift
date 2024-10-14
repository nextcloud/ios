//
//  NCPushNotification.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 26/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications
import NextcloudKit

class NCPushNotification {
    static let shared = NCPushNotification()
    let keychain = NCKeychain()
    var pushKitToken: String = ""

    func pushNotification() {
        if pushKitToken.isEmpty { return }
        for tblAccount in NCManageDatabase.shared.getAllTableAccount() {
            let token = keychain.getPushNotificationToken(account: tblAccount.account)
            if token != pushKitToken {
                if token != nil {
                    unsubscribingNextcloudServerPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user, withSubscribing: true)
                } else {
                    subscribingNextcloudServerPushNotification(account: tblAccount.account, urlBase: tblAccount.urlBase, user: tblAccount.user)
                }
            }
        }
    }

    func applicationdidReceiveRemoteNotification(userInfo: [AnyHashable: Any], completion: @escaping (_ result: UIBackgroundFetchResult) -> Void) {
        if let message = userInfo["subject"] as? String {
            for tblAccount in NCManageDatabase.shared.getAllTableAccount() {
                if let privateKey = keychain.getPushNotificationPrivateKey(account: tblAccount.account),
                   let decryptedMessage = NCPushNotificationEncryption.shared().decryptPushNotification(message, withDevicePrivateKey: privateKey),
                   let jsonData = decryptedMessage.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            let nid = jsonObject["nid"] as? Int
                            let delete = jsonObject["delete"] as? Bool
                            let deleteAll = jsonObject["delete-all"] as? Bool
                            if let delete, delete, let nid {
                                removeNotificationWithNotificationId(nid, usingDecryptionKey: privateKey)
                            } else if let deleteAll, deleteAll {
                                cleanAllNotifications()
                            }
                        } else {
                            print("Failed to convert JSON data to dictionary.")
                        }
                    } catch {
                        print("Error parsing")
                    }
                }
            }
        }
        completion(UIBackgroundFetchResult.noData)
    }

    func subscribingNextcloudServerPushNotification(account: String, urlBase: String, user: String) {
        if pushKitToken.isEmpty { return }

        NCPushNotificationEncryption.shared().generatePushNotificationsKeyPair(account)
        guard let pushTokenHash = NCEndToEndEncryption.shared().createSHA512(pushKitToken),
              let pushPublicKey = keychain.getPushNotificationPublicKey(account: account),
              let pushDevicePublicKey = String(data: pushPublicKey, encoding: .utf8)  else { return }
        let proxyServerPath = NCBrandOptions.shared.pushNotificationServerProxy

        NextcloudKit.shared.subscribingPushNotification(serverUrl: urlBase, pushTokenHash: pushTokenHash, devicePublicKey: pushDevicePublicKey, proxyServerUrl: proxyServerPath, account: account) { account, deviceIdentifier, signature, publicKey, _, error in
            if error == .success, let deviceIdentifier, let signature, let publicKey {
                let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
                let options = NKRequestOptions(customUserAgent: userAgent)

                NextcloudKit.shared.subscribingPushProxy(proxyServerUrl: proxyServerPath, pushToken: self.pushKitToken, deviceIdentifier: deviceIdentifier, signature: signature, publicKey: publicKey, account: account, options: options) { account, _, error in
                    if error == .success {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Subscribed to Push Notification server & proxy successfully")
                        self.keychain.setPushNotificationToken(account: account, token: self.pushKitToken)
                        self.keychain.setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: deviceIdentifier)
                        self.keychain.setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: signature)
                        self.keychain.setPushNotificationSubscribingPublicKey(account: account, publicKey: publicKey)
                    }
                }
            }
        }
    }

    func unsubscribingNextcloudServerPushNotification(account: String, urlBase: String, user: String, withSubscribing subscribing: Bool) {
        guard let deviceIdentifier = keychain.getPushNotificationDeviceIdentifier(account: account),
              let signature = keychain.getPushNotificationDeviceIdentifierSignature(account: account),
              let publicKey = keychain.getPushNotificationSubscribingPublicKey(account: account) else { return }

        NextcloudKit.shared.unsubscribingPushNotification(serverUrl: urlBase, account: account) { _, _, error in
            if error == .success {
                let proxyServerPath = NCBrandOptions.shared.pushNotificationServerProxy
                let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
                let options = NKRequestOptions(customUserAgent: userAgent)

                NextcloudKit.shared.unsubscribingPushProxy(proxyServerUrl: proxyServerPath, deviceIdentifier: deviceIdentifier, signature: signature, publicKey: publicKey, account: account, options: options) { account, _, error in
                    if error == .success {
                        NextcloudKit.shared.nkCommonInstance.writeLog("[INFO] Unsubscribed to Push Notification server & proxy successfully")
                        self.keychain.setPushNotificationPublicKey(account: account, data: nil)
                        self.keychain.setPushNotificationSubscribingPublicKey(account: account, publicKey: nil)
                        self.keychain.setPushNotificationPrivateKey(account: account, data: nil)
                        self.keychain.setPushNotificationToken(account: account, token: nil)
                        self.keychain.setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: nil)
                        self.keychain.setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: nil)

                        if !self.pushKitToken.isEmpty && subscribing {
                            self.subscribingNextcloudServerPushNotification(account: account, urlBase: urlBase, user: user)
                        }
                    }
                }
            }
        }
    }

    func removeNotificationWithNotificationId(_ notificationId: Int, usingDecryptionKey key: Data) {
        // Check in pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            for request in requests {
                if let message = request.content.userInfo["subject"] as? String,
                   let decryptedMessage = NCPushNotificationEncryption.shared().decryptPushNotification(message, withDevicePrivateKey: key),
                   let jsonData = decryptedMessage.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            let nid = jsonObject["nid"] as? Int
                            if nid == notificationId {
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [request.identifier])
                            }
                        } else {
                            print("Failed to convert JSON data to dictionary.")
                        }
                    } catch {
                        print("Error parsing")
                    }
                }
            }
        }
        // Check in delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            for notification in notifications {
                if let message = notification.request.content.userInfo["subject"] as? String,
                   let decryptedMessage = NCPushNotificationEncryption.shared().decryptPushNotification(message, withDevicePrivateKey: key),
                   let jsonData = decryptedMessage.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                            let nid = jsonObject["nid"] as? Int
                            if nid == notificationId {
                                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.request.identifier])
                            }
                        } else {
                            print("Failed to convert JSON data to dictionary.")
                        }
                    } catch {
                        print("Error parsing")
                    }
                }
            }
        }
    }

    func registerForRemoteNotificationsWithDeviceToken(_ deviceToken: Data) {
        self.pushKitToken = NCPushNotificationEncryption.shared().string(withDeviceToken: deviceToken)
        pushNotification()
    }

    func cleanAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
