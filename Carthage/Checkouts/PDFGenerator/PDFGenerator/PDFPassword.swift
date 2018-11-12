//
//  PDFPassword.swift
//  PDFGenerator
//
//  Created by Suguru Kishimoto on 2016/07/08.
//
//

import Foundation
import UIKit

public struct PDFPassword {
    static let NoPassword = ""
    fileprivate static let PasswordLengthMax = 32
    let userPassword: String
    let ownerPassword: String
    
    public init(user userPassword: String, owner ownerPassword: String) {
        self.userPassword = userPassword
        self.ownerPassword = ownerPassword
    }
    
    public init(_ password: String) {
        self.init(user: password, owner: password)
    }
    
    func toDocumentInfo() -> [AnyHashable : Any] {
        var info: [AnyHashable : Any] = [:]
        if userPassword != type(of: self).NoPassword {
            info[String(kCGPDFContextUserPassword)] = userPassword
        }
        if ownerPassword != type(of: self).NoPassword {
            info[String(kCGPDFContextOwnerPassword)] = ownerPassword
        }
        return info
    }
    
    func verify() throws {
        guard userPassword.canBeConverted(to: String.Encoding.ascii) else {
            throw PDFGenerateError.invalidPassword(userPassword)
        }
        guard userPassword.characters.count <= type(of: self).PasswordLengthMax else {
            throw PDFGenerateError.tooLongPassword(userPassword.characters.count)
        }
        
        guard ownerPassword.canBeConverted(to: String.Encoding.ascii) else {
            throw PDFGenerateError.invalidPassword(ownerPassword)
        }
        guard ownerPassword.characters.count <= type(of: self).PasswordLengthMax else {
            throw PDFGenerateError.tooLongPassword(ownerPassword.characters.count)
        }
    }
}

extension PDFPassword: ExpressibleByStringLiteral {
    public init(unicodeScalarLiteral value: String) {
        self.init(value)
    }
    
    public init(extendedGraphemeClusterLiteral value: String) {
        self.init(value)
    }
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
}
