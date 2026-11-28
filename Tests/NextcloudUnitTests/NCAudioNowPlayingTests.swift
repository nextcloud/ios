// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Simon St-Michel
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MediaPlayer
import Testing
@testable import Nextcloud

@Suite("Audio Now Playing information")
struct NCAudioNowPlayingTests {
    // MARK: - Metadata

    @Test("Fallback title is the file name without its extension")
    func fallbackTitleDropsExtension() {
        let metadata = NCAudioNowPlayingMetadata.fallback(fileName: "My Song.mp3", previewData: nil)

        #expect(metadata.title == "My Song")
        #expect(metadata.artist == nil)
    }

    @Test("Fallback keeps a file name that has no extension")
    func fallbackWithoutExtension() {
        let metadata = NCAudioNowPlayingMetadata.fallback(fileName: "Recording", previewData: nil)

        #expect(metadata.title == "Recording")
    }

    @Test("Embedded tags replace the file-based fallback")
    func embeddedTagsWin() {
        let fallback = NCAudioNowPlayingMetadata.fallback(fileName: "track01.flac", previewData: Data([1]))
        let embedded = NCAudioNowPlayingMetadata(title: "Real Title", artist: "Artist", albumTitle: "Album", artworkData: Data([2]))

        let result = fallback.overridden(by: embedded)

        #expect(result == embedded)
    }

    @Test("Empty embedded values keep the fallback")
    func emptyEmbeddedValuesKeepFallback() {
        let fallback = NCAudioNowPlayingMetadata.fallback(fileName: "track01.flac", previewData: Data([1]))
        let embedded = NCAudioNowPlayingMetadata(title: "  ", artist: "Artist", albumTitle: "", artworkData: Data())

        let result = fallback.overridden(by: embedded)

        #expect(result.title == "track01")
        #expect(result.artist == "Artist")
        #expect(result.albumTitle == nil)
        #expect(result.artworkData == Data([1]))
    }

    @Test("Missing embedded metadata keeps the fallback unchanged")
    func missingEmbeddedMetadata() {
        let fallback = NCAudioNowPlayingMetadata.fallback(fileName: "track01.flac", previewData: nil)

        #expect(fallback.overridden(by: nil) == fallback)
    }

    // MARK: - Now Playing dictionary

    @Test("Playing state publishes title, position, duration and rate")
    func playingInfo() {
        let metadata = NCAudioNowPlayingMetadata(title: "Song", artist: "Artist", albumTitle: "Album")

        let info = NCAudioNowPlayingController.nowPlayingInfo(metadata: metadata, duration: 180, elapsedTime: 42, isPlaying: true)

        #expect(info[MPMediaItemPropertyTitle] as? String == "Song")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Artist")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Album")
        #expect(info[MPMediaItemPropertyPlaybackDuration] as? Double == 180)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double == 42)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
    }

    @Test("Paused state publishes a zero playback rate")
    func pausedInfo() {
        let info = NCAudioNowPlayingController.nowPlayingInfo(metadata: NCAudioNowPlayingMetadata(title: "Song"), duration: 180, elapsedTime: 42, isPlaying: false)

        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0)
    }

    @Test("Unknown duration and invalid position are not published as-is")
    func unknownDuration() {
        let info = NCAudioNowPlayingController.nowPlayingInfo(metadata: NCAudioNowPlayingMetadata(title: "Song"), duration: 0, elapsedTime: .nan, isPlaying: true)

        #expect(info[MPMediaItemPropertyPlaybackDuration] == nil)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double == 0)
        #expect(info[MPMediaItemPropertyArtist] == nil)
        #expect(info[MPMediaItemPropertyArtwork] == nil)
    }
}
