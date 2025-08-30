// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import UserNotifications
import NextcloudKit

class NCPushNotification {
    static let shared = NCPushNotification()
    let global = NCGlobal.shared

    func subscribingNextcloudServerPushNotification(account: String, urlBase: String) async {
        let preferences = NCPreferences()
        let proxyServerUrl = NCBrandOptions.shared.pushNotificationServerProxy
        guard !proxyServerUrl.isEmpty,
              let keyPair = NCPushNotificationEncryption.shared().generatePushNotificationsKeyPair(account),
              let pushTokenHash = NCEndToEndEncryption.shared().createSHA512(preferences.deviceTokenPushNotification),
              let devicePublicKey = String(data: keyPair.publicKey, encoding: .utf8) else {
            return
        }

        let responsePN = await NextcloudKit.shared.subscribingPushNotificationAsync(serverUrl: urlBase,
                                                                                    pushTokenHash: pushTokenHash,
                                                                                    devicePublicKey: devicePublicKey,
                                                                                    proxyServerUrl: proxyServerUrl, account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: urlBase,
                                                                                            name: "subscribingPushNotification")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        guard responsePN.error == .success,
              let deviceIdentifier = responsePN.deviceIdentifier,
              let signature = responsePN.signature,
              let publicKey = responsePN.publicKey
        else {
            nkLog(tag: self.global.logTagPN, emoji: .error, message: "Subscribed to Push Notification Server \(urlBase) with error \(responsePN.error.errorDescription)")
            return
        }

        let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
        let options = NKRequestOptions(customUserAgent: userAgent)

        let responsePushProxy = await NextcloudKit.shared.subscribingPushProxyAsync(proxyServerUrl: proxyServerUrl,
                                                                                    pushToken: preferences.deviceTokenPushNotification,
                                                                                    deviceIdentifier: deviceIdentifier,
                                                                                    signature: signature,
                                                                                    publicKey: publicKey,
                                                                                    account: account,
                                                                                    options: options, taskHandler: { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: proxyServerUrl,
                                                                                            name: "subscribingPushProxy")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        })

        guard responsePushProxy.error == .success else {
            nkLog(tag: self.global.logTagPN, emoji: .error, message: "Subscribed to Push Notification Server Proxy \(proxyServerUrl) with error \(responsePushProxy.error.errorDescription)")
            return
        }

        preferences.setPushNotificationPrivateKey(account: account, data: keyPair.privateKey)
        preferences.setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: deviceIdentifier)
        preferences.setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: signature)
        preferences.setPushNotificationSubscribingPublicKey(account: account, publicKey: publicKey)
    }

    func unsubscribingNextcloudServerPushNotification(account: String, urlBase: String) async {
        let preferences = NCPreferences()
        guard let deviceIdentifier = preferences.getPushNotificationDeviceIdentifier(account: account),
              let signature = preferences.getPushNotificationDeviceIdentifierSignature(account: account),
              let publicKey = preferences.getPushNotificationSubscribingPublicKey(account: account) else {
            return
        }

        let responsePN = await NextcloudKit.shared.unsubscribingPushNotificationAsync(serverUrl: urlBase,
                                                                                      account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: urlBase,
                                                                                            name: "unsubscribingPushNotification")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        let userAgent = String(format: "%@  (Strict VoIP)", NCBrandOptions.shared.getUserAgent())
        let options = NKRequestOptions(customUserAgent: userAgent)
        let proxyServerUrl = NCBrandOptions.shared.pushNotificationServerProxy
        let responseProxy = await NextcloudKit.shared.unsubscribingPushProxyAsync(proxyServerUrl: proxyServerUrl,
                                                                                  deviceIdentifier: deviceIdentifier,
                                                                                  signature: signature,
                                                                                  publicKey: publicKey,
                                                                                  account: account,
                                                                                  options: options) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: account,
                                                                                            path: NCBrandOptions.shared.pushNotificationServerProxy,
                                                                                            name: "unsubscribingPushProxy")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }

        nkLog(tag: self.global.logTagPN, emoji: .info, message: "Unsubscribed to Push Notification Server \(urlBase) with error \(responsePN.error.errorDescription)")
        nkLog(tag: self.global.logTagPN, emoji: .info, message: "Unsubscribed to Push Notification Server Proxy \(proxyServerUrl) with error \(responseProxy.error.errorDescription)")
    }

    func applicationdidReceiveRemoteNotification(userInfo: [AnyHashable: Any], completion: @escaping (_ result: UIBackgroundFetchResult) -> Void) {
        if let message = userInfo["subject"] as? String {
            for tblAccount in NCManageDatabase.shared.getAllTableAccount() {
                if let privateKey = NCPreferences().getPushNotificationPrivateKey(account: tblAccount.account),
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
