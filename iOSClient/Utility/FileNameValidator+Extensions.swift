//
//  FileNameValidator+Extensions.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 26.08.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import NextcloudKit

extension FileNameValidator {
    static func checkFileName(_ filename: String, account: String?, capabilities: NCCapabilities.Capabilities) -> NKError? {
        let fileNameValidator = FileNameValidator(forbiddenFileNames: capabilities.capabilityForbiddenFileNames, forbiddenFileNameBasenames: capabilities.capabilityForbiddenFileNameBasenames, forbiddenFileNameCharacters: capabilities.capabilityForbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.capabilityForbiddenFileNameExtensions)
        return fileNameValidator.checkFileName(filename)
    }

    static func checkFolderPath(_ folderPath: String, account: String?, capabilities: NCCapabilities.Capabilities) -> Bool {
        let fileNameValidator = FileNameValidator(forbiddenFileNames: capabilities.capabilityForbiddenFileNames, forbiddenFileNameBasenames: capabilities.capabilityForbiddenFileNameBasenames, forbiddenFileNameCharacters: capabilities.capabilityForbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.capabilityForbiddenFileNameExtensions)
        return fileNameValidator.checkFolderPath(folderPath)
    }
}
