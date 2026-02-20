// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import RealmSwift
import NextcloudKit

class tableCapabilities: Object {
    @Persisted(primaryKey: true) var account = ""
    @Persisted var capabilities: Data?
    @Persisted var editors: Data?
}
