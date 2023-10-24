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

    @objc var requestPasscodeAtStart: Bool {
        get {
            let keychainOLD = Keychain(service: NCGlobal.shared.serviceShareKeyChain)
            if let value = keychainOLD["notPasscodeAtStart"], !value.isEmpty {
                if value == "true" {
                    keychain["requestPasscodeAtStart"] = "false"
                } else if value == "false" {
                    keychain["requestPasscodeAtStart"] = "true"
                }
                keychainOLD["notPasscodeAtStart"] = nil
            }
            if let value = try? keychain.get("requestPasscodeAtStart"), let result = Bool(value) {
                return result
            }
            return false
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

    var intro: Bool {
        get {
            migrate(key: "intro")
            if let value = try? keychain.get("intro"), let result = Bool(value) {
                return result
            }
            return false
        }
        set {
            keychain["intro"] = String(newValue)
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

    // MARK: -

    private func migrate(key: String) {
        let keychainOLD = Keychain(service: NCGlobal.shared.serviceShareKeyChain)
        if let value = keychainOLD[key], !value.isEmpty {
            keychain[key] = value
            keychainOLD[key] = nil
        }
    }

    @objc func removeAll() {
        try? keychain.removeAll()
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
}
