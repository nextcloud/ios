//
//  PKCS12.swift
//  Nextcloud
//
//  Created by Milen on 15.05.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
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

typealias UserCertificate = (data: Data, password: String)

enum PKCS12Error: Error {
    case wrongPasswordError(String)
    case runtimeError(String)
}

class PKCS12 {
    let label: String?
    let keyID: NSData?
    let trust: SecTrust?
    let certChain: [SecTrust]?
    let identity: SecIdentity?

    /// Creates a PKCS12 instance from a piece of data.
    /// - Parameters:
    ///   - pkcs12Data: the actual data we want to parse.
    ///   - password: he password required to unlock the PKCS12 data.
    public init(pkcs12Data: Data, password: String, onIncorrectPassword: () -> Void) throws {
        let importPasswordOption: NSDictionary = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let secError: OSStatus = SecPKCS12Import(pkcs12Data as NSData, importPasswordOption, &items)
        if secError == errSecAuthFailed {
            onIncorrectPassword()
            throw PKCS12Error.wrongPasswordError("Wrong password entered")
        }
        guard let theItemsCFArray = items else { throw PKCS12Error.runtimeError("") }
        let theItemsNSArray: NSArray = theItemsCFArray as NSArray
        guard let dictArray = theItemsNSArray as? [[String: AnyObject]] else {
            throw PKCS12Error.runtimeError("")
        }

        label = dictArray.element(for: kSecImportItemLabel)
        keyID = dictArray.element(for: kSecImportItemKeyID)
        trust = dictArray.element(for: kSecImportItemTrust)
        certChain = dictArray.element(for: kSecImportItemCertChain)
        identity = dictArray.element(for: kSecImportItemIdentity)
    }

    static func urlCredential(for pkcs12: PKCS12) -> URLCredential? {
        guard let identity = pkcs12.identity else {
            return nil
        }

        // In most cases you should pass nil to the certArray parameter. You only need to supply an array of intermediate certificates if the server needs those intermediate certificates to authenticate the client. Typically this isn’t necessary because the server already has a copy of the relevant intermediate certificates.
        // See https://developer.apple.com/documentation/foundation/urlcredential/1418121-init
        return URLCredential(identity: identity, certificates: nil, persistence: .none)
    }
}

private extension Array where Element == [String: AnyObject] {
    func element<T>(for key: CFString) -> T? {
        for dictElement in self {
            if let value = dictElement[key as String] as? T {
                return value
            }
        }
        return nil
    }
}
