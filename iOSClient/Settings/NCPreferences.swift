// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Rasmus Wøldike
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import KeychainAccess
import NextcloudKit

final class NCPreferences: NSObject {
    private static let userDefaultsMigrationKey = "NCPreferencesUserDefaultsMigrationVersion"
    private static let userDefaultsMigrationVersion = 1

    let keychain = Keychain(service: "com.nextcloud.keychain")
    private let userDefaults: UserDefaults

    override init() {
        userDefaults = UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup) ?? .standard
        super.init()
        migrateUserDefaultsToAppGroupIfNeeded()
    }

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
            setUserDefaults(newValue.rawValue, forKey: "ScanDocumentTypeFilter")
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

    /// Тhe deadline date when the wrong passcode attempt lockout expires.
    var passcodeLockoutEnd: Date? {
        get {
            if let value = try? keychain.get("passcodeLockoutEnd"), let result = Double(value) {
                return Date(timeIntervalSince1970: result)
            }
            return nil
        }
        set {
            keychain["passcodeLockoutEnd"] = newValue.map { String($0.timeIntervalSince1970) }
        }
    }

    func clearPasscodeFailures() {
        passcodeCounterFail = 0
        passcodeCounterFailReset = 0
        passcodeLockoutEnd = nil
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

    var saveCameraMediaToCameraRoll: Bool {
        get {
            return getBoolPreference(key: "saveCameraMediaToCameraRoll", defaultValue: true)
        }
        set {
            setUserDefaults(newValue, forKey: "saveCameraMediaToCameraRoll")
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

    var deviceTokenPushNotification: String {
        get {
            return getStringPreference(key: "deviceTokenPushNotification", defaultValue: "")
        }
        set {
            setUserDefaults(newValue, forKey: "deviceTokenPushNotification")
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
        let userDefaultsKey = "personalfilesonly" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getPersonalFilesOnly(account: String) -> Bool {
        return getBoolPreference(key: "personalfilesonly", account: account, defaultValue: false)
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
        guard let certificate = getEndToEndCertificate(account: account), !certificate.isEmpty,
              let publicKey = getEndToEndPublicKey(account: account), !publicKey.isEmpty,
              let privateKey = getEndToEndPrivateKey(account: account), !privateKey.isEmpty,
              let passphrase = getEndToEndPassphrase(account: account), !passphrase.isEmpty else {
            return false
        }
        return true
    }

    /// Indicates that the locally active E2EE key set no longer matches the
    /// key currently published by the server. The key material is retained so
    /// it can continue to decrypt older storage spaces, but it must not write.
    func isEndToEndServerKeyStale(account: String) -> Bool {
        getBoolPreference(
            key: "EndToEndServerKeyStale",
            account: account,
            defaultValue: false
        )
    }

    func setEndToEndServerKeyStale(account: String, stale: Bool) {
        let key = "EndToEndServerKeyStale_\(account)"
        setUserDefaults(stale, forKey: key)
    }

    /// Archives the current E2EE credentials as an immutable Keychain item.
    ///
    /// Repeated attempts with unchanged credentials reuse the existing
    /// snapshot. The archive index is written only after the snapshot itself,
    /// so callers can safely stop before clearing the active credentials if
    /// either Keychain operation fails.
    @discardableResult
    func archiveCurrentEndToEndKeySet(account: String) throws -> NCEndToEndKeySet? {
        guard let candidate = NCEndToEndKeySet(
            certificate: getEndToEndCertificate(account: account),
            privateKey: getEndToEndPrivateKey(account: account),
            publicKey: getEndToEndPublicKey(account: account),
            passphrase: getEndToEndPassphrase(account: account)
        ) else {
            return nil
        }

        let archivedKeySets = try getArchivedEndToEndKeySets(account: account)
        if let existingKeySet = archivedKeySets.first(where: { $0.containsSameKeyMaterial(as: candidate) }) {
            return existingKeySet
        }

        let snapshotKey = archivedEndToEndKeySetKey(account: account, identifier: candidate.identifier)
        let snapshotData = try JSONEncoder().encode(candidate)
        try keychain.set(snapshotData, key: snapshotKey)

        do {
            let identifiers = archivedKeySets.map(\.identifier) + [candidate.identifier]
            let indexData = try JSONEncoder().encode(identifiers)
            try keychain.set(indexData, key: archivedEndToEndKeySetIndexKey(account: account))
        } catch {
            try? keychain.remove(snapshotKey)
            throw error
        }

        return candidate
    }

    /// Returns E2EE snapshots in archival order without exposing mutation APIs.
    func getArchivedEndToEndKeySets(account: String) throws -> [NCEndToEndKeySet] {
        let indexKey = archivedEndToEndKeySetIndexKey(account: account)
        guard let indexData = try keychain.getData(indexKey) else {
            return []
        }

        let identifiers = try JSONDecoder().decode([String].self, from: indexData)
        return try identifiers.map { identifier in
            let snapshotKey = archivedEndToEndKeySetKey(account: account, identifier: identifier)
            guard let snapshotData = try keychain.getData(snapshotKey) else {
                throw CocoaError(.fileReadCorruptFile)
            }

            let keySet = try JSONDecoder().decode(NCEndToEndKeySet.self, from: snapshotData)
            guard keySet.identifier == identifier else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return keySet
        }
    }

    /// Clears only the active credentials, preserving archived key sets.
    func clearCurrentKeysEndToEnd(account: String) {
        setEndToEndCertificate(account: account, certificate: nil)
        setEndToEndPrivateKey(account: account, privateKey: nil)
        setEndToEndPublicKey(account: account, publicKey: nil)
        setEndToEndPassphrase(account: account, passphrase: nil)
    }

    /// Clears active and archived E2EE credentials for explicit local removal.
    func clearAllKeysEndToEnd(account: String) {
        clearCurrentKeysEndToEnd(account: account)
        setEndToEndServerKeyStale(account: account, stale: false)

        let snapshotPrefix = archivedEndToEndKeySetPrefix(account: account)
        for key in keychain.allKeys().filter({ $0.hasPrefix(snapshotPrefix) }) {
            try? keychain.remove(key)
        }
        try? keychain.remove(archivedEndToEndKeySetIndexKey(account: account))
    }

    private func archivedEndToEndKeySetIndexKey(account: String) -> String {
        "EndToEndArchivedKeySetIndex_" + account
    }

    private func archivedEndToEndKeySetPrefix(account: String) -> String {
        "EndToEndArchivedKeySet_" + account + "_"
    }

    private func archivedEndToEndKeySetKey(account: String, identifier: String) -> String {
        archivedEndToEndKeySetPrefix(account: account) + identifier
    }

    // MARK: - PUSH NOTIFICATION

    func getPushNotificationPrivateKey(account: String) -> Data? {
        let key = "PushPrivateKey" + account
        return try? keychain.getData(key)
    }

    func setPushNotificationPrivateKey(account: String, data: Data?) {
        let key = "PushPrivateKey" + account
        keychain[data: key] = data
    }

    func getPushNotificationPublicKey(account: String) -> Data? {
        let key = "PushPublicKey" + account
        return try? keychain.getData(key)
    }

    func setPushNotificationPublicKey(account: String, data: Data?) {
        let key = "PushPublicKey" + account
        keychain[data: key] = data
    }

    func getPushNotificationSubscribingPublicKey(account: String) -> String? {
        let key = "PushSubscribingPublicKey" + account
        return try? keychain.get(key)
    }

    func setPushNotificationSubscribingPublicKey(account: String, publicKey: String?) {
        let key = "PushSubscribingPublicKey" + account
        keychain[key] = publicKey
    }

    func getPushNotificationDeviceIdentifier(account: String) -> String? {
        let value = getStringPreference(key: "PushDeviceIdentifier", account: account, defaultValue: "")
        return value
    }

    func setPushNotificationDeviceIdentifier(account: String, deviceIdentifier: String?) {
        let userDefaultsKey = "PushDeviceIdentifier" + "_\(account)"
        setUserDefaults(deviceIdentifier, forKey: userDefaultsKey)
    }

    func getPushNotificationDeviceIdentifierSignature(account: String) -> String? {
        let key = "PushDeviceIdentifierSignature" + account
        return try? keychain.get(key)
    }

    func setPushNotificationDeviceIdentifierSignature(account: String, deviceIdentifierSignature: String?) {
        let key = "PushDeviceIdentifierSignature" + account
        keychain[key] = deviceIdentifierSignature
    }

    func clearAllKeysPushNotification(account: String) {
        setPushNotificationPrivateKey(account: account, data: nil)
        setPushNotificationPublicKey(account: account, data: nil)
        setPushNotificationSubscribingPublicKey(account: account, publicKey: nil)
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

    // MARK: - Upload Asset (autoupload folder)

    func setUploadUseAutoUploadFolder(account: String, value: Bool) {
        let userDefaultsKey = "UploadUseAutoUploadFolder" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getUploadUseAutoUploadFolder(account: String) -> Bool {
        return getBoolPreference(key: "UploadUseAutoUploadFolder", account: account, defaultValue: false)

    }

    func setUploadUseAutoUploadSubFolder(account: String, value: Bool) {
        let userDefaultsKey = "UploadUseAutoUploadSubFolder" + "_\(account)"
        setUserDefaults(value, forKey: userDefaultsKey)
    }

    func getUploadUseAutoUploadSubFolder(account: String) -> Bool {
        return getBoolPreference(key: "UploadUseAutoUploadSubFolder", account: account, defaultValue: false)
    }

    func cleaningWeek() -> Bool {
        let date = Date()
        let year = Calendar.current.component(.yearForWeekOfYear, from: date)
        let week = Calendar.current.component(.weekOfYear, from: date)
        let weekString = String(format: "%04d-W%02d", year, week) // "2025-W44"
        let value = getStringPreference(key: "cleaningWeek", defaultValue: "")

        return (value == weekString) ? false : true
    }

    func setDoneCleaningWeek() {
        let date = Date()
        let year = Calendar.current.component(.yearForWeekOfYear, from: date)
        let week = Calendar.current.component(.weekOfYear, from: date)
        let weekString = String(format: "%04d-W%02d", year, week) // "2025-W44"
        setUserDefaults(weekString, forKey: "cleaningWeek")
    }

    // MARK: - Media Viewer

    var mediaViewerRepeatCurrentItem: Bool {
        get {
            getBoolPreference(
                key: "mediaViewerRepeatCurrentItem",
                defaultValue: false
            )
        }
        set {
            setUserDefaults(
                newValue,
                forKey: "mediaViewerRepeatCurrentItem"
            )
        }
    }

    var mediaViewerAutoAdvance: Bool {
        get {
            getBoolPreference(
                key: "mediaViewerAutoAdvance",
                defaultValue: false
            )
        }
        set {
            setUserDefaults(
                newValue,
                forKey: "mediaViewerAutoAdvance"
            )
        }
    }

    // MARK: - Video

    func alwaysUseVLCForVideo(account: String, ocId: String) -> Bool {
        let key = alwaysUseVLCForVideoKey(
            account: account,
            ocId: ocId
        )

        return userDefaults.object(forKey: key) as? Bool == true
    }

    func setAlwaysUseVLCForVideo(_ value: Bool, account: String, ocId: String) {
        let key = alwaysUseVLCForVideoKey(
            account: account,
            ocId: ocId
        )

        if value {
            userDefaults.set(true, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func alwaysUseVLCForVideoKey(
        account: String,
        ocId: String
    ) -> String {
        "Preferences_alwaysUseVLCForVideo_\(account)|\(ocId)"
    }

    // MARK: -

    private func migrate(key: String) {
        let keychainOLD = Keychain(service: "Crypto Cloud")
        if let value = keychainOLD[key], !value.isEmpty {
            keychain[key] = value
            keychainOLD[key] = nil
        }
    }

    private func migrateUserDefaultsToAppGroupIfNeeded() {
        guard userDefaults !== UserDefaults.standard,
              Bundle.main.object(forInfoDictionaryKey: "NSExtension") == nil,
              userDefaults.integer(forKey: Self.userDefaultsMigrationKey) < Self.userDefaultsMigrationVersion else {
            return
        }

        defer {
            userDefaults.set(Self.userDefaultsMigrationVersion, forKey: Self.userDefaultsMigrationKey)
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let legacyPreferences = UserDefaults.standard.persistentDomain(forName: bundleIdentifier) else {
            return
        }

        for (key, value) in legacyPreferences where key.hasPrefix("Preferences_") {
            if userDefaults.object(forKey: key) == nil {
                userDefaults.set(value, forKey: key)
            }
        }
    }

    func removeAll() {
        try? keychain.removeAll()
    }

    private func setUserDefaults(_ value: Any?, forKey key: String) {
        let keyPreferences = "Preferences_\(key)"
        userDefaults.set(value, forKey: keyPreferences)
    }

    private func getBoolPreference(key: String, account: String? = nil, defaultValue: Bool) -> Bool {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = userDefaults.object(forKey: userDefaultsKey) as? Bool {
            return value
        }

        if let value = try? keychain.get(keychainKey), let boolValue = Bool(value) {
            userDefaults.set(boolValue, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return boolValue
        }

        return defaultValue
    }

    private func getStringPreference(key: String, account: String? = nil, defaultValue: String) -> String {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = userDefaults.object(forKey: userDefaultsKey) as? String {
            return value
        }

        if let value = try? keychain.get(keychainKey) {
            userDefaults.set(value, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return value
        }

        return defaultValue
    }

    private func getIntPreference(key: String, account: String? = nil, defaultValue: Int) -> Int {
        let suffix = account ?? ""
        let userDefaultsKey = account != nil ? "Preferences_\(key)_\(suffix)" : "Preferences_\(key)"
        let keychainKey = account != nil ? "\(key)\(suffix)" : key

        if let value = userDefaults.object(forKey: userDefaultsKey) as? Int {
            return value
        }

        if let value = try? keychain.get(keychainKey), let intValue = Int(value) {
            userDefaults.set(intValue, forKey: userDefaultsKey)
            try? keychain.remove(keychainKey)
            return intValue
        }

        return defaultValue
    }
}
