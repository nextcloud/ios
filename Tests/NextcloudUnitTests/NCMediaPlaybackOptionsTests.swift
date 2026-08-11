// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Testing
@testable import Nextcloud

@Suite("Media playback completion options")
@MainActor
struct NCMediaPlaybackOptionsTests {
    @Test("Playback stops when no completion option is enabled")
    func stopsByDefault() {
        let options = NCMediaPlaybackOptions(preferences: nil)

        #expect(options.completionAction == .stop)
    }

    @Test("Automatic advance plays the next compatible item")
    func advancesAutomatically() {
        let options = NCMediaPlaybackOptions(preferences: nil)

        options.toggleAutoAdvance()

        #expect(options.completionAction == .playNextItem)
    }

    @Test("Disabling repeat restores normal stop behavior")
    func disablingRepeatRestoresStop() {
        let options = NCMediaPlaybackOptions(preferences: nil)

        options.toggleRepeat()
        #expect(options.completionAction == .repeatCurrentItem)

        options.toggleRepeat()
        #expect(options.completionAction == .stop)
    }

    @Test("Repeat takes precedence over automatic advance")
    func repeatTakesPrecedence() {
        let options = NCMediaPlaybackOptions(preferences: nil)

        options.toggleAutoAdvance()
        options.toggleRepeat()

        #expect(options.completionAction == .repeatCurrentItem)

        options.toggleRepeat()

        #expect(options.completionAction == .playNextItem)
    }

    @Test("Playback options restore and save their preferences")
    func persistsPlaybackOptions() {
        let preferences = NCPreferences()
        let originalRepeat = preferences.mediaViewerRepeatCurrentItem
        let originalAutoAdvance = preferences.mediaViewerAutoAdvance

        defer {
            preferences.mediaViewerRepeatCurrentItem = originalRepeat
            preferences.mediaViewerAutoAdvance = originalAutoAdvance
        }

        preferences.mediaViewerRepeatCurrentItem = true
        preferences.mediaViewerAutoAdvance = false

        let options = NCMediaPlaybackOptions(preferences: preferences)

        #expect(options.isRepeatEnabled)
        #expect(!options.isAutoAdvanceEnabled)

        options.toggleRepeat()
        options.toggleAutoAdvance()

        #expect(!preferences.mediaViewerRepeatCurrentItem)
        #expect(preferences.mediaViewerAutoAdvance)
    }
}
