// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2020 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import CryptoKit

extension String {
    var alphanumeric: String {
        return self.components(separatedBy: CharacterSet.alphanumerics.inverted).joined().lowercased()
    }

    ///
    /// Escapes `<`, `>`, and `&` for use in SwiftRichString markup as it appears in the activity view.
    ///
    var escapedForMarkup: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    var isNumber: Bool {
        return self.allSatisfy { character in
            character.isNumber
        }
    }

    public var uppercaseInitials: String? {
        let initials = self.components(separatedBy: .whitespaces)
            .reduce("", {
                guard $0.count < 2, let nextLetter = $1.first else { return $0 }
                return $0 + nextLetter.uppercased()
            })
        return initials.isEmpty ? nil : initials
    }

    func formatSecondsToString(_ seconds: TimeInterval) -> String {
        if seconds.isNaN {
            return "00:00:00"
        }
        let sec = Int(seconds.truncatingRemainder(dividingBy: 60))
        let min = Int(seconds.truncatingRemainder(dividingBy: 3600) / 60)
        let hour = Int(seconds / 3600)
        return String(format: "%02d:%02d:%02d", hour, min, sec)
    }

    func md5() -> String {
        let digest = Insecure.MD5.hash(data: self.data(using: .utf8) ?? Data())
        return digest.map {
            String(format: "%02hhx", $0)
        }.joined()
    }

    /* DEPRECATED iOS 13
    func md5() -> String {
        // https://stackoverflow.com/a/32166735/9506784

        let length = Int(CC_MD5_DIGEST_LENGTH)
        let messageData = self.data(using: .utf8) ?? Data()
        var digestData = Data(count: length)

        _ = digestData.withUnsafeMutableBytes { digestBytes -> UInt8 in
            messageData.withUnsafeBytes { messageBytes -> UInt8 in
                if let messageBytesBaseAddress = messageBytes.baseAddress, let digestBytesBlindMemory = digestBytes.bindMemory(to: UInt8.self).baseAddress {
                    let messageLength = CC_LONG(messageData.count)
                    CC_MD5(messageBytesBaseAddress, messageLength, digestBytesBlindMemory)
                }
                return 0
            }
        }

        return digestData.map { String(format: "%02hhx", $0) }.joined()
    }
    */

    var urlEncoded: String? {
        // +        for historical reason, most web servers treat + as a replacement of whitespace
        // ?, &     mark query pararmeter which should not be part of a url string, but added seperately
        let urlAllowedCharSet = CharacterSet.urlQueryAllowed.subtracting(["+", "?", "&"])
        return addingPercentEncoding(withAllowedCharacters: urlAllowedCharSet)
    }
}

extension StringProtocol {
    var firstUppercased: String { lowercased().prefix(1).uppercased() + dropFirst() }
}
