// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@Observable class NCStatusMessageModel {
    @ObservationIgnored let statusPresets: [Status] = [
        .init(emoji: "📅", title: "In a meeting", detail: "In 1 hour"),
        .init(emoji: "🚌", title: "Commuting", detail: "In 30 minutes"),
        .init(emoji: "🏡", title: "Working remotely", detail: "Today"),
        .init(emoji: "🤒", title: "Out sick", detail: "Today"),
        .init(emoji: "🌴", title: "Vacationing", detail: "Don't clear")
    ]

    var statusText: String = ""
    var selectedStatus: Status?
//  e var clearAfter: ClearAfter = .dontClear
    var emojiText: String = "😀"
}
