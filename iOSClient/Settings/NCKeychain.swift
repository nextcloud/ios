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
import UIKit
import KeychainAccess

@objc class NCKeychain: NSObject {

    let keychain = Keychain(service: "com.nextcloud.keychain")

    var showDescription: Bool {
        get {
            if let value = try? keychain.get("showDescription"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["showDescription"] = String(newValue)
        }
    }

    var showRecommendedFiles: Bool {
        get {
            if let value = try? keychain.get("showRecommendedFiles"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["showRecommendedFiles"] = String(newValue)
        }
    }

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
            if let value = try? keychain.get("passcodeBlock"), !value.isEmpty {
                return value
            }
            return nil
        }
        set {
            keychain["passcodeBlock"] = newValue
        }
    }

    var resetAppCounterFail: Bool {
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

    var requestPasscodeAtStart: Bool {
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

    var touchFaceID: Bool {
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

    var presentPasscode: Bool {
        return passcode != nil && requestPasscodeAtStart
    }

    var incrementalNumber: String {
        migrate(key: "incrementalnumber")
        var incrementalString = String(format: "%04ld", 0)
        if let value = try? keychain.get("incrementalnumber"), var result = Int(value) {
            result += 1
            incrementalString = String(format: "%04ld", result)
        }
        keychain["incrementalnumber"] = incrementalString
        return incrementalString
    }

    var showHiddenFiles: Bool {
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

    var formatCompatibility: Bool {
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

    var disableFilesApp: Bool {
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

    var livePhoto: Bool {
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

    var disableCrashservice: Bool {
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

    var logLevel: Int {
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

    var accountRequest: Bool {
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

    var removePhotoCameraRoll: Bool {
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

    var privacyScreenEnabled: Bool {
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

    var cleanUpDay: Int {
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

    var appearanceAutomatic: Bool {
        get {
            if let value = try? keychain.get("appearanceAutomatic"), let result = Bool(value) {
                return result
            }
            return true
        }
        set {
            keychain["appearanceAutomatic"] = String(newValue)
        }
    }

    var appearanceInterfaceStyle: UIUserInterfaceStyle {
        get {
            if let value = try? keychain.get("appearanceInterfaceStyle") {
                if value == "light" {
                    return .light
                } else {
                    return .dark
                }
            }
            return .light
        }
        set {
            if newValue == .light {
                keychain["appearanceInterfaceStyle"] = "light"
            } else {
                keychain["appearanceInterfaceStyle"] = "dark"
            }
        }
    }

    var screenAwakeMode: AwakeMode {
        get {
            if let value = try? keychain.get("screenAwakeMode") {
                if value == "off" {
                    return .off
                } else if value == "on" {
                    return .on
                } else {
                    return .whileCharging
                }
            }
            return .off
        }
        set {
            if newValue == .off {
                keychain["screenAwakeMode"] = "off"
            } else if newValue == .on {
                keychain["screenAwakeMode"] = "on"
            } else {
                keychain["screenAwakeMode"] = "whileCharging"
            }
        }
    }

    var fileNameType: Bool {
        get {
            if let value = try? keychain.get("fileNameType"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["fileNameType"] = String(newValue)
        }
    }

    var fileNameOriginal: Bool {
        get {
            if let value = try? keychain.get("fileNameOriginal"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["fileNameOriginal"] = String(newValue)
        }
    }

    var fileNameMask: String {
        get {
            if let value = try? keychain.get("fileNameMask") {
                return value
            }
            return ""
        }
        set {
            keychain["fileNameMask"] = String(newValue)
        }
    }

    // MARK: -

    @objc func getPassword(account: String) -> String {
        let key = "password" + account
        migrate(key: key)
        let password = (try? keychain.get(key)) ?? ""
        return password
    }

    func setPassword(account: String, password: String?) {
        let key = "password" + account
        keychain[key] = password
    }

    func setPersonalFilesOnly(account: String, value: Bool) {
        let key = "personalFilesOnly" + account
        keychain[key] = String(value)
    }

    func getPersonalFilesOnly(account: String) -> Bool {
        let key = "personalFilesOnly" + account
        if let value = try? keychain.get(key), let result = Bool(value) {
            return result
        } else {
            return false
        }
    }

    /* OBSOLETE
    func setDirectoryOnTop(account: String, value: Bool) {
        let key = "directoryOnTop" + account
        keychain[key] = String(value)
    }

    func getDirectoryOnTop(account: String) -> Bool {
        let key = "directoryOnTop" + account
        if let value = try? keychain.get(key), let result = Bool(value) {
            return result
        } else {
            return true
        }
    }
    */

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
        let capabilities = NCCapabilities.shared.getCapabilities(account: account)
        guard let certificate = getEndToEndCertificate(account: account), !certificate.isEmpty,
              let publicKey = getEndToEndPublicKey(account: account), !publicKey.isEmpty,
              let privateKey = getEndToEndPrivateKey(account: account), !privateKey.isEmpty,
              let passphrase = getEndToEndPassphrase(account: account), !passphrase.isEmpty,
              NCGlobal.shared.e2eeVersions.contains(capabilities.capabilityE2EEApiVersion) else { return false }
        return true
    }

    func clearAllKeysEndToEnd(account: String) {
        setEndToEndCertificate(account: account, certificate: nil)
        setEndToEndPrivateKey(account: account, privateKey: nil)
        setEndToEndPublicKey(account: account, publicKey: nil)
        setEndToEndPassphrase(account: account, passphrase: nil)
    }

    // MARK: - PUSHNOTIFICATION

    func getPushNotificationPublicKey(account: String) -> Data? {
        let key = "PNPublicKey" + account
        return try? keychain.getData(key)
    }

    @objc func setPushNotificationPublicKey(account: String, data: Data?) {
        let key = "PNPublicKey" + account
        keychain[data: key] = data
    }

    func getPushNotificationPrivateKey(account: String) -> Data? {
        let key = "PNPrivateKey" + account
        return try? keychain.getData(key)
    }

    @objc func setPushNotificationPrivateKey(account: String, data: Data?) {
        let key = "PNPrivateKey" + account
        keychain[data: key] = data
    }

    func getPushNotificationSubscribingPublicKey(account: String) -> String? {
        let key = "PNSubscribingPublicKey" + account
        return try? keychain.get(key)
    }

    func setPushNotificationSubscribingPublicKey(account: String, publicKey: String?) {
        let key = "PNSubscribingPublicKey" + account
        keychain[key] = publicKey
    }

    func getPushNotificationToken(account: String) -> String? {
        let key = "PNToken" + account
        return try? keychain.get(key)
    }

    func setPushNotificationToken(account: String, token: String?) {
        let key = "PNToken" + account
        keychain[key] = token
    }

    func getPushNotificationDeviceIdentifier(account: String) -> String? {
        let key = "PNDeviceIdentifier" + account
        return try? keychain.get(key)
    }

    func setPushNotificationDeviceIdentifier(account: String, deviceIdentifier: String?) {
        let key = "PNDeviceIdentifier" + account
        keychain[key] = deviceIdentifier
    }

    func getPushNotificationDeviceIdentifierSignature(account: String) -> String? {
        let key = "PNDeviceIdentifierSignature" + account
        return try? keychain.get(key)
    }

    func setPushNotificationDeviceIdentifierSignature(account: String, deviceIdentifierSignature: String?) {
        let key = "PNDeviceIdentifierSignature" + account
        keychain[key] = deviceIdentifierSignature
    }

    func clearAllKeysPushNotification(account: String) {
        setPushNotificationPublicKey(account: account, data: nil)
        setPushNotificationSubscribingPublicKey(account: account, publicKey: nil)
        setPushNotificationPrivateKey(account: account, data: nil)
        setPushNotificationToken(account: account, token: nil)
        setPushNotificationDeviceIdentifier(account: account, deviceIdentifier: nil)
        setPushNotificationDeviceIdentifierSignature(account: account, deviceIdentifierSignature: nil)
    }

    // MARK: - Certificates

    func setClientCertificate(account: String, p12Data: Data?, p12Password: String?) {
        var key = "ClientCertificateData" + account
        keychain[data: key] = p12Data

        key = "ClientCertificatePassword" + account
        keychain[key] = p12Password
    }

    func getClientCertificate(account: String) -> (p12Data: Data?, p12Password: String?) {
        var key = "ClientCertificateData" + account
        let data = try? keychain.getData(key)

        key = "ClientCertificatePassword" + account
        let password = keychain[key]

        return (data, password)
    }

    // MARK: - Albums

    func setAutoUploadAlbumIds(account: String, albumIds: [String]) {
        let key = "AlbumIds" + account
        keychain[key] = albumIds.joined(separator: ",")
    }

    func getAutoUploadAlbumIds(account: String) -> [String] {
        let key = "AlbumIds" + account
        return (try? keychain.get(key)?.components(separatedBy: ",")) ?? []
    }

    // MARK: -

    private func migrate(key: String) {
        let keychainOLD = Keychain(service: "Crypto Cloud")
        if let value = keychainOLD[key], !value.isEmpty {
            keychain[key] = value
            keychainOLD[key] = nil
        }
    }

    func removeAll() {
        try? keychain.removeAll()
    }
}
