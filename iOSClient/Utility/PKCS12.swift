//
//  PKCS12.swift
//  Nextcloud
//
//  Created by Milen on 15.05.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

typealias UserCertificate = (data: Data, password: String)

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
    public init(pkcs12Data: Data, password: String) {
        let importPasswordOption: NSDictionary
            = [kSecImportExportPassphrase as NSString: password]
        var items: CFArray?
        let secError: OSStatus
            = SecPKCS12Import(pkcs12Data as NSData,
                              importPasswordOption, &items)
        guard secError == errSecSuccess else {
            if secError == errSecAuthFailed {
                NSLog("Incorrect password?")
            }
            fatalError("Error trying to import PKCS12 data")
        }
        guard let theItemsCFArray = items else { fatalError() }
        let theItemsNSArray: NSArray = theItemsCFArray as NSArray
        guard let dictArray
            = theItemsNSArray as? [[String: AnyObject]]
        else {
            fatalError()
        }

        label = dictArray.element(for: kSecImportItemLabel)
        keyID = dictArray.element(for: kSecImportItemKeyID)
        trust = dictArray.element(for: kSecImportItemTrust)
        certChain = dictArray.element(for: kSecImportItemCertChain)
        identity = dictArray.element(for: kSecImportItemIdentity)
    }

    static func urlCredential(for userCertificate: UserCertificate?) -> URLCredential? {
        guard let userCertificate = userCertificate else { return nil }

        let p12Contents = PKCS12(pkcs12Data: userCertificate.data, password: userCertificate.password)

        guard let identity = p12Contents.identity else {
            return nil
        }

        // In most cases you should pass nil to the certArray parameter. You only need to supply an array of intermediate certificates if the server needs those intermediate certificates to authenticate the client. Typically this isn’t necessary because the server already has a copy of the relevant intermediate certificates.
        // See https://developer.apple.com/documentation/foundation/urlcredential/1418121-init
        return URLCredential(identity: identity,
                             certificates: nil,
                             persistence: .none)

    }
}

extension Array where Element == [String: AnyObject] {
    func element<T>(for key: CFString) -> T? {
        for dictElement in self {
            if let value = dictElement[key as String] as? T {
                return value
            }
        }
        return nil
    }
}

