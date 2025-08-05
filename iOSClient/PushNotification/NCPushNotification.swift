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
    let global = NCGlobal.shared

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
                            nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to convert JSON data dictionary.")
                        }
                    } catch {
                        nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to parsing JSON data dictionary.")
                    }
                }
            }
        }
        completion(UIBackgroundFetchResult.noData)
    }

    func subscribingNextcloudServerPushNotification(account: String, urlBase: String, user: String, pushKitToken: String?) {
        guard let keyPair = NCPushNotificationEncryption.shared().generatePushNotificationsKeyPair(account),
              let pushKitToken,
              let pushTokenHash = NCEndToEndEncryption.shared().createSHA512(pushKitToken),
              let pushPublicKey = keychain.getPushNotificationPublicKey(account: account),
              let pushDevicePublicKey = String(data: pushPublicKey, encoding: .utf8) else {
            return
        }

        NCKeychain().setPushNotificationPublicKey(account: account, data: keyPair.publicKey)
        NCKeychain().setPushNotificationPrivateKey(account: account, data: keyPair.privateKey)

        let proxyServerPath = NCBrandOptions.shared.pushNotificationServerProxy

        NextcloudKit.shared.subscribingPushNotification(serverUrl: urlBase, pushTokenHash: pushTokenHash, devicePublicKey: pushDevicePublicKey, proxyServerUrl: proxyServerPath, account: account) { account, deviceIdentifier, signature, publicKey, _, error in
            if error == .success,
               let deviceIdentifier,
               let signature,
               let publicKey {
                let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
                let options = NKRequestOptions(customUserAgent: userAgent)

                nkLog(tag: self.global.logTagPN, emoji: .info, message: "Subscribed to Push Notification Server \(account)")

                NextcloudKit.shared.subscribingPushProxy(proxyServerUrl: proxyServerPath, pushToken: pushKitToken, deviceIdentifier: deviceIdentifier, signature: signature, publicKey: publicKey, account: account, options: options) { account, _, error in
                    if error == .success {
                        nkLog(tag: self.global.logTagPN, emoji: .info, message: "Subscribed to Push Notification Server Proxy \(account)")

                        self.keychain.setPushNotificationToken(account: account, token: pushKitToken)
                        self.keychain.setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: deviceIdentifier)
                        self.keychain.setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: signature)
                        self.keychain.setPushNotificationSubscribingPublicKey(account: account, publicKey: publicKey)
                    } else {
                        nkLog(tag: self.global.logTagPN, emoji: .error, message: "Subscribed to Push Notification Server Proxy with error \(error.errorDescription) \(account)")
                    }
                }
            } else {
                nkLog(tag: self.global.logTagPN, emoji: .error, message: "Subscribed to Push Notification Server with error \(error.errorDescription) \(account)")
            }
        }
    }

    func unsubscribingNextcloudServerPushNotification(account: String, urlBase: String, user: String) {
        guard let deviceIdentifier = keychain.getPushNotificationDeviceIdentifier(account: account),
              let signature = keychain.getPushNotificationDeviceIdentifierSignature(account: account),
              let publicKey = keychain.getPushNotificationSubscribingPublicKey(account: account) else { return }

        NextcloudKit.shared.unsubscribingPushNotification(serverUrl: urlBase, account: account) { _, _, error in
            if error == .success {
                nkLog(tag: self.global.logTagPN, emoji: .info, message: "Unsubscribed to Push Notification Server \(account)")

                let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
                let options = NKRequestOptions(customUserAgent: userAgent)

                NextcloudKit.shared.unsubscribingPushProxy(proxyServerUrl: NCBrandOptions.shared.pushNotificationServerProxy, deviceIdentifier: deviceIdentifier, signature: signature, publicKey: publicKey, account: account, options: options) { _, _, error in
                    if error == .success {
                        nkLog(tag: self.global.logTagPN, emoji: .info, message: "Unsubscribed to Push Notification Server Proxy \(account)")
                    } else {
                        nkLog(tag: self.global.logTagPN, emoji: .error, message: "Unsubscribed to Push Notification Server Proxy with error \(error.errorDescription) \(account)")
                    }
                }
            } else {
                nkLog(tag: self.global.logTagPN, emoji: .error, message: "Unsubscribed to Push Notification Server with error \(error.errorDescription) \(account)")
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
                            nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to convert JSON data dictionary.")
                        }
                    } catch {
                        nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to parsing JSON data dictionary.")
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
                            nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to convert JSON data dictionary.")
                        }
                    } catch {
                        nkLog(tag: self.global.logTagPN, emoji: .error, message: "Failed to parsing JSON data dictionary.")
                    }
                }
            }
        }
    }

    func cleanAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}
