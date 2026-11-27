// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Simon St-Michel
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Describes the audio file shown by the system "Now Playing" surfaces:
/// Lock Screen, Control Center, Dynamic Island and AirPlay receivers.
///
/// Two sources are combined:
/// - the Nextcloud file itself (its name and the server preview), always available;
/// - tags embedded in the audio file (ID3, iTunes, Vorbis…), available for most music.
///
/// Artwork is kept as `Data` instead of `UIImage` so the value stays `Sendable`.
struct NCAudioNowPlayingMetadata: Sendable, Equatable {
    var title: String
    var artist: String?
    var albumTitle: String?
    var artworkData: Data?

    init(title: String = "", artist: String? = nil, albumTitle: String? = nil, artworkData: Data? = nil) {
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.artworkData = artworkData
    }

    /// Builds the fallback shown when the audio file has no embedded tags:
    /// the file name without its extension and the server preview, if any.
    static func fallback(fileName: String, previewData: Data?) -> NCAudioNowPlayingMetadata {
        let name = (fileName as NSString).deletingPathExtension
        return NCAudioNowPlayingMetadata(title: name.isEmpty ? fileName : name, artworkData: previewData)
    }

    /// Returns a copy where every non-empty value of `preferred` replaces the value of `self`.
    /// Missing or empty values in `preferred` keep the current value.
    func overridden(by preferred: NCAudioNowPlayingMetadata?) -> NCAudioNowPlayingMetadata {
        guard let preferred else {
            return self
        }

        return NCAudioNowPlayingMetadata(
            title: preferred.title.nonEmpty ?? title,
            artist: preferred.artist?.nonEmpty ?? artist,
            albumTitle: preferred.albumTitle?.nonEmpty ?? albumTitle,
            artworkData: (preferred.artworkData?.isEmpty == false) ? preferred.artworkData : artworkData
        )
    }
}

private extension String {
    /// `nil` when the string is empty or only contains whitespace.
    var nonEmpty: String? {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self
    }
}
