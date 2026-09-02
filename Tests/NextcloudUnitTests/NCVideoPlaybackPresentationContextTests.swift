// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Video playback presentation context")
struct NCVideoPlaybackPresentationContextTests {
    @Test("User-initiated playback starts with visible controls")
    func userInitiatedPlaybackShowsControls() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .userInitiated
        )

        context.prepareForPlaybackStart()

        #expect(context.shouldShowControlsOnStart)
        #expect(context.playbackTransition == .idle)
        #expect(!context.shouldSuppressAutomaticControlsPresentation)
    }

    @Test("Automatic advancement starts without presenting controls")
    func automaticAdvanceSuppressesControls() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .automaticAdvance
        )

        context.prepareForPlaybackStart()

        #expect(!context.shouldShowControlsOnStart)
        #expect(context.playbackTransition == .automaticStart)
        #expect(context.shouldSuppressAutomaticControlsPresentation)

        context.finishPlaybackTransition()

        #expect(context.playbackTransition == .idle)
        #expect(!context.shouldSuppressAutomaticControlsPresentation)
        #expect(context.shouldShowControlsOnStart)
    }

    @Test("Repeat restart suppresses automatic control presentation")
    func repeatRestartSuppressesControls() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .userInitiated
        )

        context.beginRepeatRestart()

        #expect(context.playbackTransition == .repeatRestart)
        #expect(context.shouldSuppressAutomaticControlsPresentation)

        context.finishPlaybackTransition()

        #expect(context.playbackTransition == .idle)
        #expect(!context.shouldSuppressAutomaticControlsPresentation)
    }

    @Test("Seeking is represented by the shared transition state")
    func seekingUsesSharedTransition() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .userInitiated
        )

        context.beginSeeking()

        #expect(context.interaction == .seeking)
        #expect(context.isSeeking)
        #expect(context.shouldSuppressAutomaticControlsPresentation)

        context.finishSeeking()

        #expect(!context.isSeeking)
    }

    @Test("Playback callbacks preserve seeking and complete automatic start")
    func playbackCallbackPreservesSeekingAndCompletesAutomaticStart() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .automaticAdvance
        )

        context.prepareForPlaybackStart()
        context.beginSeeking()
        context.finishPlaybackTransition()

        #expect(context.isSeeking)
        #expect(context.playbackTransition == .idle)
        #expect(context.shouldShowControlsOnStart)
        #expect(context.shouldSuppressAutomaticControlsPresentation)

        context.finishSeeking()

        #expect(!context.shouldSuppressAutomaticControlsPresentation)
    }

    @Test("Reset clears playback and interaction transitions")
    func resetClearsAllTransitions() {
        var context = NCVideoPlaybackPresentationContext(
            startReason: .automaticAdvance
        )

        context.prepareForPlaybackStart()
        context.beginSeeking()
        context.reset()

        #expect(context.playbackTransition == .idle)
        #expect(context.interaction == .idle)
        #expect(!context.shouldSuppressAutomaticControlsPresentation)
    }
}
