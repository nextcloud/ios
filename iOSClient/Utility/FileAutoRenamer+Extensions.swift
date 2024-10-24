//
//  FileAutoRenamer+Extensions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 10.10.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import NextcloudKit

extension FileAutoRenamer {
    private func setup(account: String?) {
        let capabilities = NCCapabilities.shared.getCapabilities(account: account)
        FileAutoRenamer.shared.setup(forbiddenFileNameCharacters: capabilities.capabilityForbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.capabilityForbiddenFileNameExtensions)
    }

    func rename(_ filename: String, isFolderPath: Bool = false, account: String?) -> String {
        setup(account: account)
        return FileAutoRenamer.shared.rename(filename: filename, isFolderPath: isFolderPath)
    }
}
