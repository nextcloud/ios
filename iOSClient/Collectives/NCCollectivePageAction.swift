// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A page action that needs user input or confirmation before it is sent to the server.
enum NCCollectivePageAction: Equatable {
    case create(parent: NCCollectivePage)
    case rename(NCCollectivePage)
    case trash(NCCollectivePage)
}
