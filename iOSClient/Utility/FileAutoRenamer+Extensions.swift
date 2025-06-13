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
        guard let account else {
            return filename
        }
        let capabilities = NCCapabilities.shared.getCapabilitiesBlocking(for: account)
        let autoRenamer = FileAutoRenamer(forbiddenFileNameCharacters: capabilities.forbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.forbiddenFileNameExtensions)
        return autoRenamer.rename(filename: filename, isFolderPath: isFolderPath)
    }
}
