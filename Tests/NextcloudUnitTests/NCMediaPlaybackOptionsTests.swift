// SPDX-FileCopyrightText: 2026 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-2.0-or-later

import Testing
@testable import Nextcloud

@Suite("Media playback completion options")
@MainActor
struct NCMediaPlaybackOptionsTests {
    @Test("Playback stops when no completion option is enabled")
    func stopsByDefault() {
        let options = NCMediaPlaybackOptions()

        #expect(options.completionAction == .stop)
    }

    @Test("Automatic advance plays the next compatible item")
    func advancesAutomatically() {
        let options = NCMediaPlaybackOptions()

        options.toggleAutoAdvance()

        #expect(options.completionAction == .playNextItem)
    }

    @Test("Disabling repeat restores normal stop behavior")
    func disablingRepeatRestoresStop() {
        let options = NCMediaPlaybackOptions()

        options.toggleRepeat()
        #expect(options.completionAction == .repeatCurrentItem)

        options.toggleRepeat()
        #expect(options.completionAction == .stop)
    }

    @Test("Repeat takes precedence over automatic advance")
    func repeatTakesPrecedence() {
        let options = NCMediaPlaybackOptions()

        options.toggleAutoAdvance()
        options.toggleRepeat()

        #expect(options.completionAction == .repeatCurrentItem)

        options.toggleRepeat()

        #expect(options.completionAction == .playNextItem)
    }
}
