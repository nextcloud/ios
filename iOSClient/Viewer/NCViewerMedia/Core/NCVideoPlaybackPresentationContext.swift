// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

struct NCVideoPlaybackPresentationContext: Equatable {
    enum StartReason: Equatable {
        case userInitiated
        case automaticAdvance

        var shouldShowControlsOnStart: Bool {
            self == .userInitiated
        }
    }

    enum PlaybackTransition: Equatable {
        case idle
        case automaticStart
        case repeatRestart
    }

    enum Interaction: Equatable {
        case idle
        case seeking
    }

    // Player state callbacks can arrive while the user is seeking, so playback
    // transitions and user interactions must remain independent.
    private(set) var startReason: StartReason
    private(set) var playbackTransition = PlaybackTransition.idle
    private(set) var interaction = Interaction.idle

    var shouldShowControlsOnStart: Bool {
        startReason.shouldShowControlsOnStart
    }

    var shouldSuppressAutomaticControlsPresentation: Bool {
        playbackTransition != .idle || interaction != .idle
    }

    var isSeeking: Bool {
        interaction == .seeking
    }

    init(startReason: StartReason) {
        self.startReason = startReason
    }

    mutating func updateStartReason(_ startReason: StartReason) {
        self.startReason = startReason
    }

    mutating func prepareForPlaybackStart() {
        playbackTransition = startReason == .automaticAdvance ? .automaticStart : .idle
    }

    mutating func beginRepeatRestart() {
        playbackTransition = .repeatRestart
    }

    mutating func beginSeeking() {
        interaction = .seeking
    }

    mutating func finishPlaybackTransition() {
        guard playbackTransition != .idle else {
            return
        }

        let completedTransition = playbackTransition
        playbackTransition = .idle

        if completedTransition == .automaticStart {
            startReason = .userInitiated
        }
    }

    mutating func finishSeeking() {
        guard interaction == .seeking else {
            return
        }

        interaction = .idle
    }

    mutating func reset() {
        playbackTransition = .idle
        interaction = .idle
    }
}
