// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit
import UIKit

extension FileAutoRenamer {
    static func rename(_ filename: String, isFolderPath: Bool = false, capabilities: NKCapabilities.Capabilities) -> String {
        let autoRenamer = FileAutoRenamer(forbiddenFileNameCharacters: capabilities.forbiddenFileNameCharacters, forbiddenFileNameExtensions: capabilities.forbiddenFileNameExtensions)
        return autoRenamer.rename(filename: filename, isFolderPath: isFolderPath)
    }
}
