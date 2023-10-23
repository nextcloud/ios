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

class NCKeychain {

    let keychain = Keychain(service: "com.nextcloud.keychain")
    let keychainOLD = Keychain(service: NCGlobal.shared.serviceShareKeyChain)

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

    var passcode: String {
        get {
            /* MIGRATION OLD */
            if let value = keychainOLD["passcodeBlock"], !value.isEmpty {
                keychain["passcodeBlock"] = value
                keychainOLD["passcodeBlock"] = nil
            }
            if let value = try? keychain.get("passcodeBlock") {
                return value
            } else {
                return ""
            }
        }
        set {
            keychain["passcodeBlock"] = newValue
        }
    }
}
