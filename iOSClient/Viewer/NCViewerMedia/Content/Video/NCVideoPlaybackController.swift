// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import MobileVLCKit
import NextcloudKit

// MARK: - Video Playback Engine

struct NCVideoAVPreparedPlayback {
    let url: URL
    let player: AVPlayer
    let item: AVPlayerItem
}

struct NCVideoVLCPreparedPlayback {
    let url: URL
    let media: VLCMedia
}

enum NCVideoPlaybackEngine {
    case loading
    case avFoundation(preparedPlayback: NCVideoAVPreparedPlayback)
    case vlc(preparedPlayback: NCVideoVLCPreparedPlayback)
    case failed(message: String)
}

// MARK: - Video Playback Controller

// Resolves AVFoundation playback or VLC fallback for video pages.
@MainActor
final class NCVideoPlaybackController: ObservableObject {
    static let shared = NCVideoPlaybackController()

    // MARK: - Published State

    @Published private(set) var engine: NCVideoPlaybackEngine = .loading

    // MARK: - Private State

    private var avProbePlayer: AVPlayer?
    private var avProbeItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?

    private var currentOcId: String?
    private var currentEtag: String?
    private var currentURL: URL?
    private var currentFileName: String?
    private var loadToken = UUID()

    private init() { }

    // MARK: - Public API

    func isCurrentVideo(
        ocId: String,
        etag: String,
        url: URL
    ) -> Bool {
        currentOcId == ocId &&
        currentEtag == etag &&
        currentURL == url
    }
    // Used for remote videos before the final playback URL is known.
    func isCurrentVideo(
        ocId: String,
        etag: String
    ) -> Bool {
        currentOcId == ocId &&
        currentEtag == etag &&
        currentURL != nil
    }
    // Reuses the current player when the requested video is already loaded.
    func loadVideo(
        metadata: tableMetadata,
        url: URL,
        fileName: String,
        userAgent: String?,
        httpHeaders: [String: String]
    ) {
        if isSameLoadedVideo(
            metadata: metadata,
            url: url
        ) {
            return
        }

        stop()

        let token = UUID()
        loadToken = token
        currentOcId = metadata.ocId
        currentEtag = metadata.etag
        currentURL = url
        currentFileName = fileName
        engine = .loading

        if url.isFileURL,
           !isValidLocalFile(url: url) {
            engine = .failed(message: "")
            return
        }

        configureAudioSession()

        if shouldUseVLCWithoutAVFoundation(
            url: url,
            fileName: fileName
        ) {
            resolveWithVLC(
                url: url,
                userAgent: userAgent,
                token: token
            )
            return
        }

        prepareAVFoundation(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            httpHeaders: url.isFileURL ? [:] : httpHeaders,
            token: token
        )
    }

    func stopIfCurrent(ocId: String) {
        guard currentOcId == ocId else {
            return
        }

        stop()
    }
    // Releases the current prepared playback state and pending AVFoundation probes.
    func stop() {
        loadToken = UUID()

        statusObservation?.invalidate()
        statusObservation = nil

        avProbePlayer?.pause()
        avProbePlayer = nil
        avProbeItem = nil

        currentOcId = nil
        currentEtag = nil
        currentURL = nil
        currentFileName = nil

        engine = .loading
    }

    // MARK: - AVFoundation

    private func prepareAVFoundation(
        metadata: tableMetadata,
        url: URL,
        userAgent: String?,
        httpHeaders: [String: String],
        token: UUID
    ) {
        let assetOptions: [String: Any]? = httpHeaders.isEmpty
            ? nil
            : [
                "AVURLAssetHTTPHeaderFieldsKey": httpHeaders
            ]

        let asset = AVURLAsset(
            url: url,
            options: assetOptions
        )

        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)

        player.actionAtItemEnd = .pause

        avProbeItem = item
        avProbePlayer = player

        statusObservation = item.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else {
                    return
                }

                guard self.isCurrentLoad(
                    url: url,
                    token: token
                ) else {
                    return
                }

                switch item.status {
                case .readyToPlay:
                    self.resolveWithAVFoundation(
                        url: url,
                        player: player,
                        item: item,
                        token: token
                    )

                case .failed:
                    self.resolveWithVLC(
                        url: url,
                        userAgent: userAgent,
                        token: token
                    )

                case .unknown:
                    break

                @unknown default:
                    self.resolveWithVLC(
                        url: url,
                        userAgent: userAgent,
                        token: token
                    )
                }
            }
        }
    }

    private func resolveWithAVFoundation(
        url: URL,
        player: AVPlayer,
        item: AVPlayerItem,
        token: UUID
    ) {
        guard loadToken == token,
              avProbePlayer === player,
              avProbeItem === item else {
            return
        }

        statusObservation?.invalidate()
        statusObservation = nil

        let preparedPlayback = NCVideoAVPreparedPlayback(
            url: url,
            player: player,
            item: item
        )

        engine = .avFoundation(preparedPlayback: preparedPlayback)
    }

    // MARK: - VLC

    private func resolveWithVLC(
        url: URL,
        userAgent: String?,
        token: UUID
    ) {
        guard isCurrentLoad(
            url: url,
            token: token
        ) else {
            return
        }

        statusObservation?.invalidate()
        statusObservation = nil

        avProbePlayer?.pause()
        avProbePlayer = nil
        avProbeItem = nil

        let media = VLCMedia(url: url)

        if let userAgent,
           !userAgent.isEmpty,
           !url.isFileURL {
            media.addOption(":http-user-agent=\(userAgent)")
        }

        let preparedPlayback = NCVideoVLCPreparedPlayback(
            url: url,
            media: media
        )

        engine = .vlc(preparedPlayback: preparedPlayback)
    }

    // MARK: - State Helpers

    private func isSameLoadedVideo(
        metadata: tableMetadata,
        url: URL
    ) -> Bool {
        currentOcId == metadata.ocId &&
        currentEtag == metadata.etag &&
        currentURL == url
    }

    private func isCurrentLoad(
        url: URL,
        token: UUID
    ) -> Bool {
        loadToken == token && currentURL == url
    }

    // MARK: - Private Helpers

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: []
            )

            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO audio session error: \(error.localizedDescription)",
                consoleOnly: true
            )
        }
    }

    // Legacy formats go directly to VLC.
    private func shouldUseVLCWithoutAVFoundation(
        url: URL,
        fileName: String
    ) -> Bool {
        let pathExtension = resolvedVideoExtension(
            url: url,
            fileName: fileName
        )

        let legacyVideoExtensions: Set<String> = [
            "avi",
            "divx",
            "xvid",
            "wmv",
            "flv",
            "vob",
            "mkv"
        ]

        return legacyVideoExtensions.contains(pathExtension)
    }

    private func resolvedVideoExtension(
        url: URL,
        fileName: String
    ) -> String {
        let metadataExtension = URL(fileURLWithPath: fileName)
            .pathExtension
            .lowercased()

        if !metadataExtension.isEmpty {
            return metadataExtension
        }

        return url.pathExtension.lowercased()
    }

    private func isValidLocalFile(url: URL) -> Bool {
        let path = url.path

        guard FileManager.default.fileExists(atPath: path) else {
            return false
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let fileSize = attributes[.size] as? Int64,
              fileSize > 0 else {
            return false
        }

        return true
    }
}
