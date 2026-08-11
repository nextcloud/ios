// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-2.0-or-later

import Combine

enum NCMediaPlaybackCompletionAction: Equatable {
    case stop
    case repeatCurrentItem
    case playNextItem
}

@MainActor
final class NCMediaPlaybackOptions: ObservableObject {
    @Published private(set) var isRepeatEnabled = false
    @Published private(set) var isAutoAdvanceEnabled = false

    var completionAction: NCMediaPlaybackCompletionAction {
        if isRepeatEnabled {
            return .repeatCurrentItem
        }

        if isAutoAdvanceEnabled {
            return .playNextItem
        }

        return .stop
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
    }

    func toggleAutoAdvance() {
        isAutoAdvanceEnabled.toggle()
    }
}
