//
//  NCKeychain.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/10/23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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
import KeychainAccess

@objc class NCKeychain: NSObject {

    let keychain = Keychain(service: "com.nextcloud.keychain")

    var typeFilterScanDocument: NCGlobal.TypeFilterScanDocument {
        get {
            if let rawValue = try? keychain.get("ScanDocumentTypeFilter"), let value = NCGlobal.TypeFilterScanDocument(rawValue: rawValue) {
                return value
            } else {
                return .original
            }
        }
        set {
            keychain["ScanDocumentTypeFilter"] = newValue.rawValue
        }
    }

    @objc var passcode: String? {
        get {
            migrate(key: "passcodeBlock")
            if let value = try? keychain.get("passcodeBlock") {
                return value
            }
            return nil
        }
        set {
            keychain["passcodeBlock"] = newValue
        }
    }

    @objc var resetAppCounterFail: Bool {
        get {
            if let value = try? keychain.get("resetAppCounterFail"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["resetAppCounterFail"] = String(newValue)
        }
    }

    var passcodeCounterFail: Int {
        get {
            if let value = try? keychain.get("passcodeCounterFail"), let result = Int(value) {
                return result
            }
            return 0
        }
        set {
            keychain["passcodeCounterFail"] = String(newValue)
        }
    }

    var passcodeCounterFailReset: Int {
        get {
            if let value = try? keychain.get("passcodeCounterFailReset"), let result = Int(value) {
                return result
            }
            return 0
        }
        set {
            keychain["passcodeCounterFailReset"] = String(newValue)
        }
    }

    @objc var requestPasscodeAtStart: Bool {
        get {
            let keychainOLD = Keychain(service: "Crypto Cloud")
            if let value = keychainOLD["notPasscodeAtStart"], !value.isEmpty {
                if value == "true" {
                    keychain["requestPasscodeAtStart"] = "false"
                } else if value == "false" {
                    keychain["requestPasscodeAtStart"] = "true"
                }
                keychainOLD["notPasscodeAtStart"] = nil
            }
            if NCBrandOptions.shared.doNotAskPasscodeAtStartup {
                return false
            } else if let value = try? keychain.get("requestPasscodeAtStart"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["requestPasscodeAtStart"] = String(newValue)
        }
    }

    @objc var touchFaceID: Bool {
        get {
            migrate(key: "enableTouchFaceID")
            if let value = try? keychain.get("enableTouchFaceID"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["enableTouchFaceID"] = String(newValue)
        }
    }

    @objc var incrementalNumber: String {
        migrate(key: "incrementalnumber")
        var incrementalString = String(format: "%04ld", 0)
        if let value = try? keychain.get("incrementalnumber"), var result = Int(value) {
            result += 1
            incrementalString = String(format: "%04ld", result)
        }
        keychain["incrementalnumber"] = incrementalString
        return incrementalString
    }

    @objc var showHiddenFiles: Bool {
        get {
            migrate(key: "showHiddenFiles")
            if let value = try? keychain.get("showHiddenFiles"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["showHiddenFiles"] = String(newValue)
        }
    }

    @objc var formatCompatibility: Bool {
        get {
            migrate(key: "formatCompatibility")
            if let value = try? keychain.get("formatCompatibility"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["formatCompatibility"] = String(newValue)
        }
    }

    @objc var disableFilesApp: Bool {
        get {
            migrate(key: "disablefilesapp")
            if let value = try? keychain.get("disablefilesapp"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["disablefilesapp"] = String(newValue)
        }
    }

    @objc var livePhoto: Bool {
        get {
            migrate(key: "livePhoto")
            if let value = try? keychain.get("livePhoto"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["livePhoto"] = String(newValue)
        }
    }

    @objc var disableCrashservice: Bool {
        get {
            migrate(key: "crashservice")
            if let value = try? keychain.get("crashservice"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["crashservice"] = String(newValue)
        }
    }

    @objc var logLevel: Int {
        get {
            migrate(key: "logLevel")
            if let value = try? keychain.get("logLevel"), let result = Int(value) {
                return result
            }
            return 1
        }
        set {
            keychain["logLevel"] = String(newValue)
        }
    }

    @objc var accountRequest: Bool {
        get {
            migrate(key: "accountRequest")
            if let value = try? keychain.get("accountRequest"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["accountRequest"] = String(newValue)
        }
    }

    @objc var removePhotoCameraRoll: Bool {
        get {
            migrate(key: "removePhotoCameraRoll")
            if let value = try? keychain.get("removePhotoCameraRoll"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["removePhotoCameraRoll"] = String(newValue)
        }
    }

    @objc var privacyScreenEnabled: Bool {
        get {
            migrate(key: "privacyScreen")
            if let value = try? keychain.get("privacyScreen"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["privacyScreen"] = String(newValue)
        }
    }

    @objc var cleanUpDay: Int {
        get {
            migrate(key: "cleanUpDay")
            if let value = try? keychain.get("cleanUpDay"), let result = Int(value) {
                return result
            }
            return NCBrandOptions.shared.cleanUpDay
        }
        set {
            keychain["cleanUpDay"] = String(newValue)
        }
    }

    var mediaWidthImage: Int {
        get {
            migrate(key: "mediaWidthImage")
            if let value = try? keychain.get("mediaWidthImage"), let result = Int(value) {
                return result
            }
            return 80
        }
        set {
            keychain["mediaWidthImage"] = String(newValue)
        }
    }

    var textRecognitionStatus: Bool {
        get {
            migrate(key: "textRecognitionStatus")
            if let value = try? keychain.get("textRecognitionStatus"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["textRecognitionStatus"] = String(newValue)
        }
    }

    var deleteAllScanImages: Bool {
        get {
            migrate(key: "deleteAllScanImages")
            if let value = try? keychain.get("deleteAllScanImages"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["deleteAllScanImages"] = String(newValue)
        }
    }

    var qualityScanDocument: Double {
        get {
            migrate(key: "qualityScanDocument")
            if let value = try? keychain.get("qualityScanDocument"), let result = Double(value) {
                return result
            }
            return 2
        }
        set {
            keychain["qualityScanDocument"] = String(newValue)
        }
    }

    // MARK: -

    private func migrate(key: String) {
        let keychainOLD = Keychain(service: "Crypto Cloud")
        if let value = keychainOLD[key], !value.isEmpty {
            keychain[key] = value
            keychainOLD[key] = nil
        }
    }

    @objc func removeAll() {
        try? keychain.removeAll()
    }

    // MARK: -

    @objc func getPassword(account: String) -> String {
        let key = "password" + account
        migrate(key: key)
        return (try? keychain.get(key)) ?? ""
    }

    @objc func setPassword(account: String, password: String?) {
        let key = "password" + account
        keychain[key] = password
    }

    @objc func getOriginalFileName(key: String) -> Bool {
        migrate(key: key)
        if let value = try? keychain.get(key), let result = Bool(value) {
            return result
        }
        return false
    }

    @objc func setOriginalFileName(key: String, value: Bool) {
        keychain[key] = String(value)
    }

    @objc func getFileNameMask(key: String) -> String {
        migrate(key: key)
        if let value = try? keychain.get(key) {
            return value
        } else {
            return ""
        }
    }

    @objc func setFileNameMask(key: String, mask: String?) {
        keychain[key] = mask
    }

    @objc func getFileNameType(key: String) -> Bool {
        migrate(key: key)
        if let value = try? keychain.get(key), let result = Bool(value) {
            return result
        } else {
            return false
        }
    }

    @objc func setFileNameType(key: String, prefix: Bool) {
        keychain[key] = String(prefix)
    }

    // MARK: - E2EE

    func getEndToEndCertificate(account: String) -> String? {
        let key = "EndToEndCertificate_" + account
        migrate(key: key)
        return try? keychain.get(key)
    }

    func setEndToEndCertificate(account: String, certificate: String?) {
        let key = "EndToEndCertificate_" + account
        keychain[key] = certificate
    }

    func getEndToEndPrivateKey(account: String) -> String? {
        let key = "EndToEndPrivateKey_" + account
        migrate(key: key)
        return try? keychain.get(key)
    }

    func setEndToEndPrivateKey(account: String, privateKey: String?) {
        let key = "EndToEndPrivateKey_" + account
        keychain[key] = privateKey
    }

    func getEndToEndPublicKey(account: String) -> String? {
        let key = "EndToEndPublicKeyServer_" + account
        migrate(key: key)
        return try? keychain.get(key)
    }

    func setEndToEndPublicKey(account: String, publicKey: String?) {
        let key = "EndToEndPublicKeyServer_" + account
        keychain[key] = publicKey
    }

    func getEndToEndPassphrase(account: String) -> String? {
        let key = "EndToEndPassphrase_" + account
        migrate(key: key)
        return try? keychain.get(key)
    }

    func setEndToEndPassphrase(account: String, passphrase: String?) {
        let key = "EndToEndPassphrase_" + account
        keychain[key] = passphrase
    }

    func isEndToEndEnabled(account: String) -> Bool {
        guard let certificate = getEndToEndCertificate(account: account), !certificate.isEmpty,
              let publicKey = getEndToEndPublicKey(account: account), !publicKey.isEmpty,
              let privateKey = getEndToEndPrivateKey(account: account), !privateKey.isEmpty,
              let passphrase = getEndToEndPassphrase(account: account), !passphrase.isEmpty,
              NCGlobal.shared.e2eeVersions.contains(NCGlobal.shared.capabilityE2EEApiVersion) else { return false }
        return true
    }

    func clearAllKeysEndToEnd(account: String) {
        setEndToEndCertificate(account: account, certificate: nil)
        setEndToEndPrivateKey(account: account, privateKey: nil)
        setEndToEndPublicKey(account: account, publicKey: nil)
        setEndToEndPassphrase(account: account, passphrase: nil)
    }

    // MARK: - PUSHNOTIFICATION

    @objc func getPushNotificationPublicKey(account: String) -> Data? {
        let key = "PNPublicKey" + account
        return try? keychain.getData(key)
    }

    @objc func setPushNotificationPublicKey(account: String, data: Data?) {
        let key = "PNPublicKey" + account
        keychain[data: key] = data
    }

    @objc func getPushNotificationPrivateKey(account: String) -> Data? {
        let key = "PNPrivateKey" + account
        return try? keychain.getData(key)
    }

    @objc func setPushNotificationPrivateKey(account: String, data: Data?) {
        let key = "PNPrivateKey" + account
        keychain[data: key] = data
    }

    @objc func getPushNotificationSubscribingPublicKey(account: String) -> String? {
        let key = "PNSubscribingPublicKey" + account
        return try? keychain.get(key)
    }

    @objc func setPushNotificationSubscribingPublicKey(account: String, publicKey: String?) {
        let key = "PNSubscribingPublicKey" + account
        keychain[key] = publicKey
    }

    @objc func getPushNotificationToken(account: String) -> String? {
        let key = "PNToken" + account
        return try? keychain.get(key)
    }

    @objc func setPushNotificationToken(account: String, token: String?) {
        let key = "PNToken" + account
        keychain[key] = token
    }

    @objc func getPushNotificationDeviceIdentifier(account: String) -> String? {
        let key = "PNDeviceIdentifier" + account
        return try? keychain.get(key)
    }

    @objc func setPushNotificationDeviceIdentifier(account: String, deviceIdentifier: String?) {
        let key = "PNDeviceIdentifier" + account
        keychain[key] = deviceIdentifier
    }

    @objc func getPushNotificationDeviceIdentifierSignature(account: String) -> String? {
        let key = "PNDeviceIdentifierSignature" + account
        return try? keychain.get(key)
    }

    @objc func setPushNotificationDeviceIdentifierSignature(account: String, deviceIdentifierSignature: String?) {
        let key = "PNDeviceIdentifierSignature" + account
        keychain[key] = deviceIdentifierSignature
    }

    @objc func clearAllKeysPushNotification(account: String) {
        setPushNotificationPublicKey(account: account, data: nil)
        setPushNotificationSubscribingPublicKey(account: account, publicKey: nil)
        setPushNotificationPrivateKey(account: account, data: nil)
        setPushNotificationToken(account: account, token: nil)
        setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: nil)
        setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: nil)
    }
}
