// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

extension FileAutoRenamer {
    static func rename(_ filename: String, isFolderPath: Bool = false, capabilities: NKCapabilities.Capabilities) -> String {
        let autoRenamer = FileAutoRenamer(capabilities: capabilities)
        return autoRenamer.rename(filename: filename, isFolderPath: isFolderPath)
    }
}
