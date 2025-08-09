// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCCollectionViewCommon: NCEndToEndInitializeDelegate {
    func endToEndInitializeSuccess(metadata: tableMetadata?) {
        if let metadata {
            pushMetadata(metadata)
        }
    }
}
