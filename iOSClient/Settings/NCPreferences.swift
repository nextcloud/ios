// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import KeychainAccess
import NextcloudKit

final class NCPreferences: NSObject {
    let keychain = Keychain(service: "com.nextcloud.keychain")

    var showDescription: Bool {
        get {
            return getBoolPreference(key: "showDescription", defaultValue: true)
        }
        set {
            setUserDefaults(newValue, forKey: "showDescription")
        }
    }

    var showRecommendedFiles: Bool {
        get {
            return getBoolPreference(key: "showRecommendedFiles", defaultValue: true)
        }
        set {
            setUserDefaults(newValue, forKey: "showRecommendedFiles")
        }
    }

    var typeFilterScanDocument: NCGlobal.TypeFilterScanDocument {
        get {
            let rawValue = getStringPreference(key: "ScanDocumentTypeFilter", defaultValue: NCGlobal.TypeFilterScanDocument.original.rawValue)
            return NCGlobal.TypeFilterScanDocument(rawValue: rawValue) ?? .original
        }
        set {
            setUserDefaults(newValue, forKey: "ScanDocumentTypeFilter")
        }
    }

    var passcode: String? {
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
        var incrementalString = String(format: "%04ld", 0)
        let value = getStringPreference(key: "incrementalnumber", defaultValue: incrementalString)
        if var intValue = Int(value) {
            intValue += 1
            incrementalString = String(format: "%04ld", intValue)
        }
        setUserDefaults(incrementalString, forKey: "incrementalnumber")
        return incrementalString
    }

    var formatCompatibility: Bool {
        get {
            return getBoolPreference(key: "formatCompatibility", defaultValue: true)
        }
        set {
            setUserDefaults(newValue, forKey: "formatCompatibility")
        }
    }

    var disableFilesApp: Bool {
        get {
            return getBoolPreference(key: "disablefilesapp", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "disablefilesapp")
        }
    }

    var livePhoto: Bool {
        get {
            return getBoolPreference(key: "livePhoto", defaultValue: true)
        }
        set {
            setUserDefaults(newValue, forKey: "livePhoto")
        }
    }

    var disableCrashservice: Bool {
        get {
            return getBoolPreference(key: "crashservice", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "crashservice")
        }
    }

    /// Stores and retrieves the current log level from the keychain.
    var log: NKLogLevel {
        get {
            let value = getIntPreference(key: "logLevel", defaultValue: NKLogLevel.normal.rawValue)
            return NKLogLevel(rawValue: value) ?? NKLogLevel.normal
        }
        set {
            setUserDefaults(newValue.rawValue, forKey: "logLevel")
        }
    }

    var accountRequest: Bool {
        get {
            return getBoolPreference(key: "accountRequest", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "accountRequest")
        }
    }

    var removePhotoCameraRoll: Bool {
        get {
            return getBoolPreference(key: "removePhotoCameraRoll", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "removePhotoCameraRoll")
        }
    }

    var privacyScreenEnabled: Bool {
        get {
            if NCBrandOptions.shared.enforce_privacyScreenEnabled {
                return true
            }
            return getBoolPreference(key: "privacyScreen", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "privacyScreen")
        }
    }

    var cleanUpDay: Int {
        get {
            let value = getIntPreference(key: "cleanUpDay", defaultValue: NCBrandOptions.shared.cleanUpDay)
            return value
        }
        set {
            setUserDefaults(newValue, forKey: "cleanUpDay")
        }
    }

    var textRecognitionStatus: Bool {
        get {
            return getBoolPreference(key: "textRecognitionStatus", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "textRecognitionStatus")
        }
    }

    var deleteAllScanImages: Bool {
        get {
            return getBoolPreference(key: "deleteAllScanImages", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "deleteAllScanImages")
        }
    }

    var qualityScanDocument: Double {
        get {
            let value = getIntPreference(key: "qualityScanDocument", defaultValue: 2)
            return Double(value)
        }
        set {
            setUserDefaults(newValue, forKey: "qualityScanDocument")
        }
    }

    var appearanceAutomatic: Bool {
        get {
            let value = getBoolPreference(key: "appearanceAutomatic", defaultValue: true)
            return value
        }
        set {
            setUserDefaults(newValue, forKey: "appearanceAutomatic")
        }
    }

    var appearanceInterfaceStyle: UIUserInterfaceStyle {
        get {
            let value = getStringPreference(key: "appearanceInterfaceStyle", defaultValue: "light")
            if value == "light" {
                return .light
            } else {
                return .dark
            }
        }
        set {
            if newValue == .light {
                setUserDefaults("light", forKey: "appearanceInterfaceStyle")
            } else {
                setUserDefaults("dark", forKey: "appearanceInterfaceStyle")
            }
        }
    }

    var screenAwakeMode: AwakeMode {
        get {
            let value = getStringPreference(key: "screenAwakeMode", defaultValue: "off")
            if value == "off" {
                return .off
            } else if value == "on" {
                return .on
            } else {
                return .whileCharging
            }
        }
        set {
            if newValue == .off {
                setUserDefaults("off", forKey: "screenAwakeMode")
            } else if newValue == .on {
                setUserDefaults("on", forKey: "screenAwakeMode")
            } else {
                setUserDefaults("whileCharging", forKey: "screenAwakeMode")
            }
        }
    }

    var fileNameType: Bool {
        get {
            return getBoolPreference(key: "fileNameType", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "fileNameType")
        }
    }

    var fileNameOriginal: Bool {
        get {
            return getBoolPreference(key: "fileNameOriginal", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "fileNameOriginal")
        }
    }

    var fileNameMask: String {
        get {
            return getStringPreference(key: "fileNameMask", defaultValue: "")
        }
        set {
            setUserDefaults(newValue, forKey: "fileNameMask")
        }
    }

    var location: Bool {
        get {
            return getBoolPreference(key: "location", defaultValue: false)
        }
        set {
            setUserDefaults(newValue, forKey: "location")
        }
    }

    // MARK: -

    func getPassword(account: String) -> String {
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
        let userDefaultsKey = "personalFilesOnly" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getPersonalFilesOnly(account: String) -> Bool {
        return getBoolPreference(key: "personalFilesOnly", account: account, defaultValue: true)
    }

    func setFavoriteOnTop(account: String, value: Bool) {
        let userDefaultsKey = "favoriteOnTop" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getFavoriteOnTop(account: String) -> Bool {
        return getBoolPreference(key: "favoriteOnTop", account: account, defaultValue: true)
    }

    func setDirectoryOnTop(account: String, value: Bool) {
        let userDefaultsKey = "directoryOnTop" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getDirectoryOnTop(account: String) -> Bool {
        return getBoolPreference(key: "directoryOnTop", account: account, defaultValue: true)
    }

    func setShowHiddenFiles(account: String, value: Bool) {
        let userDefaultsKey = "showHiddenFiles" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getShowHiddenFiles(account: String) -> Bool {
        return getBoolPreference(key: "showHiddenFiles", account: account, defaultValue: false)
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
        guard let capabilities = NCNetworking.shared.capabilities[account],
              let certificate = getEndToEndCertificate(account: account), !certificate.isEmpty,
              let publicKey = getEndToEndPublicKey(account: account), !publicKey.isEmpty,
              let privateKey = getEndToEndPrivateKey(account: account), !privateKey.isEmpty,
              let passphrase = getEndToEndPassphrase(account: account), !passphrase.isEmpty,
              NCGlobal.shared.e2eeVersions.contains(capabilities.e2EEApiVersion) else {
            return false
        }
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

    func setPushNotificationPublicKey(account: String, data: Data?) {
        let key = "PNPublicKey" + account
        keychain[data: key] = data
    }

    func getPushNotificationPrivateKey(account: String) -> Data? {
        let key = "PNPrivateKey" + account
        return try? keychain.getData(key)
    }

    func setPushNotificationPrivateKey(account: String, data: Data?) {
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
        let userDefaultsKey = "AlbumIds" + "_\(account)"
        let value = albumIds.joined(separator: ",")
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getAutoUploadAlbumIds(account: String) -> [String] {
        let value = getStringPreference(key: "AlbumIds", account: account, defaultValue: "")
        let arrayValue = value.components(separatedBy: ",").filter { !$0.isEmpty }
        return arrayValue
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

    private func setUserDefaults(_ value: Any?, forKey key: String) {
        let keyPreferences = "Preferences_\(key)"
        UserDefaults.standard.set(value, forKey: keyPreferences)
    }

    private func getBoolPreference(key: String, account: String? = nil, defaultValue: Bool) -> Bool {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = UserDefaults.standard.object(forKey: userDefaultsKey) as? Bool {
            return value
        }

        if let value = try? keychain.get(keychainKey), let boolValue = Bool(value) {
            UserDefaults.standard.set(boolValue, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return boolValue
        }

        UserDefaults.standard.set(defaultValue, forKey: userDefaultsKey)
        return defaultValue
    }

    private func getStringPreference(key: String, account: String? = nil, defaultValue: String) -> String {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = UserDefaults.standard.object(forKey: userDefaultsKey) as? String {
            return value
        }

        if let value = try? keychain.get(keychainKey) {
            UserDefaults.standard.set(value, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return value
        }

        UserDefaults.standard.set(defaultValue, forKey: userDefaultsKey)
        return defaultValue
    }

    private func getIntPreference(key: String, account: String? = nil, defaultValue: Int) -> Int {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = UserDefaults.standard.object(forKey: userDefaultsKey) as? Int {
            return value
        }

        if let value = try? keychain.get(keychainKey), let intValue = Int(value) {
            UserDefaults.standard.set(intValue, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return intValue
        }

        UserDefaults.standard.set(defaultValue, forKey: userDefaultsKey)
        return defaultValue
    }
}
