// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

extension FileNameValidator {
    static func checkFileName(_ filename: String, account: String?, capabilities: NKCapabilities.Capabilities) -> NKError? {
        let fileNameValidator = FileNameValidator(forbiddenFileNames: capabilities.forbiddenFileNames, forbiddenFileNameBasenames: capabilities.forbiddenFileNameBasenames, forbiddenFileNameCharacters: capabilities.forbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.forbiddenFileNameExtensions)
        return fileNameValidator.checkFileName(filename)
    }

    static func checkFolderPath(_ folderPath: String, account: String?, capabilities: NKCapabilities.Capabilities) -> Bool {
        let fileNameValidator = FileNameValidator(forbiddenFileNames: capabilities.forbiddenFileNames, forbiddenFileNameBasenames: capabilities.forbiddenFileNameBasenames, forbiddenFileNameCharacters: capabilities.forbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.forbiddenFileNameExtensions)
        return fileNameValidator.checkFolderPath(folderPath)
    }
}
