//
//  FileAutoRenamer+Extensions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 10.10.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import NextcloudKit

extension FileAutoRenamer {
    static func rename(_ filename: String, isFolderPath: Bool = false, account: String?) -> String {
        let capabilities = NCCapabilities.shared.getCapabilities(account: account)
        let autoRenamer = FileAutoRenamer(forbiddenFileNameCharacters: capabilities.capabilityForbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.capabilityForbiddenFileNameExtensions)
        return autoRenamer.rename(filename: filename, isFolderPath: isFolderPath)
    }
}
