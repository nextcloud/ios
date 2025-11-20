// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@Observable class NCStatusMessageModel {
    struct StatusPreset: Identifiable, Equatable {
        let id = UUID()
        let emoji: String
        let title: String
        let clearAfter: ClearAfter
    }

    enum ClearAfter: String, CaseIterable, Identifiable {
        case dontClear = "Don't clear"
        case thirtyMinutes = "30 minutes"
        case oneHour = "1 hour"
        case fourHours = "4 hours"
        case today = "Today"
        case thisWeek = "This week"

        var id: String { rawValue }
    }

    @ObservationIgnored let statusPresets: [StatusPreset] = [
        .init(emoji: "📅", title: "In a meeting", clearAfter: .oneHour),
        .init(emoji: "🚌", title: "Commuting", clearAfter: .thirtyMinutes),
        .init(emoji: "⏳", title: "Be right back", clearAfter: .thirtyMinutes),
        .init(emoji: "🏡", title: "Working remotely", clearAfter: .thisWeek),
        .init(emoji: "🤒", title: "Out sick", clearAfter: .today),
        .init(emoji: "🌴", title: "Vacationing", clearAfter: .dontClear)
    ]

    var emojiText: String = "😀"
    var statusText: String = ""
    var clearAfter: ClearAfter = .dontClear

    func chooseStatusPreset(preset: StatusPreset) {
        emojiText = preset.emoji
        statusText = preset.title
        clearAfter = preset.clearAfter
    }

    func clearStatus() {
        emojiText = "😀"
        statusText = ""
        clearAfter = .dontClear
    }

    func submitStatus() {
        
    }
}
