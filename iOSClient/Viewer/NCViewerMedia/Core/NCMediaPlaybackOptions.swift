// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine

typealias NCMediaPlaybackAdvanceCompletion = (_ didAdvance: Bool) -> Void

// Auto-advance lookup can finish after the player reaches its end state. The
// result lets the player restore normal stopped controls when no item exists.
typealias NCMediaPlaybackAdvanceRequest = (@escaping NCMediaPlaybackAdvanceCompletion) -> Void

@MainActor
final class NCMediaPlaybackOptions: ObservableObject {
    enum CompletionAction: Equatable {
        case stop
        case repeatCurrentItem
        case playNextItem
    }

    @Published private(set) var isRepeatEnabled: Bool
    @Published private(set) var isAutoAdvanceEnabled: Bool

    private let preferences: NCPreferences?

    init(preferences: NCPreferences? = NCPreferences()) {
        self.preferences = preferences
        self.isRepeatEnabled = preferences?.mediaViewerRepeatCurrentItem ?? false
        self.isAutoAdvanceEnabled = preferences?.mediaViewerAutoAdvance ?? false
    }

    var completionAction: CompletionAction {
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
        preferences?.mediaViewerRepeatCurrentItem = isRepeatEnabled
    }

    func toggleAutoAdvance() {
        isAutoAdvanceEnabled.toggle()
        preferences?.mediaViewerAutoAdvance = isAutoAdvanceEnabled
    }
}
