// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import RealmSwift
import NextcloudKit

class tableMediaMetadataBackfill: Object {
    @Persisted(primaryKey: true) var account = ""
    @Persisted var offset = 0
    @Persisted var lastRunDate: Date?
    @Persisted var lastCompletedCycleDate: Date?

    convenience init(account: String) {
        self.init()
        self.account = account
    }
}

extension NCManageDatabase {
    
}


