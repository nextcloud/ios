//
//  FileNameValidator+Extensions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 26.08.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import NextcloudKit

extension FileNameValidator {
    private func setup(account: String?) {
        let capabilities = NCCapabilities.shared.getCapabilities(account: account)
        FileNameValidator.shared.setup(forbiddenFileNames: capabilities.capabilityForbiddenFileNames, forbiddenFileNameBasenames: capabilities.capabilityForbiddenFileNameBasenames, forbiddenFileNameCharacters: capabilities.capabilityForbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.capabilityForbiddenFileNameExtensions)
    }

    func checkFileName(_ filename: String, account: String?) -> NKError? {
        setup(account: account)
        return FileNameValidator.shared.checkFileName(filename)
    }

    func checkFolderPath(_ folderPath: String, account: String?) -> Bool {
        setup(account: account)
        return FileNameValidator.shared.checkFolderPath(folderPath)
    }
}
