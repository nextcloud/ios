// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import NextcloudKit

// MARK: - Video Playback Engine

enum NCVideoPlaybackEngine {
    case loading
    case avFoundation(url: URL)
    case vlc(url: URL)
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
        httpHeaders: [String: String],
        shouldAutoPlay: Bool
    ) {
        if isSameLoadedVideo(
            metadata: metadata,
            url: url
        ) {
            resumeCurrentPlaybackIfNeeded(shouldAutoPlay: shouldAutoPlay)
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
            engine = .failed(message: "Video file is not available.")
            return
        }

        configureAudioSession()

        if shouldUseVLCWithoutAVFoundation(
            url: url,
            fileName: fileName
        ) {
            resolveWithVLC(
                url: url,
                reason: "direct legacy format \(resolvedVideoExtension(url: url, fileName: fileName))",
                token: token
            )
            return
        }

        prepareAVFoundation(
            metadata: metadata,
            url: url,
            httpHeaders: url.isFileURL ? [:] : httpHeaders,
            shouldAutoPlay: shouldAutoPlay,
            token: token
        )
    }

    func stopIfCurrent(ocId: String) {
        guard currentOcId == ocId else {
            return
        }

        stop()
    }
    // Releases AVFoundation resources; VLC is owned by its view controller.
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
        httpHeaders: [String: String],
        shouldAutoPlay: Bool,
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
                        shouldAutoPlay: shouldAutoPlay,
                        token: token
                    )

                case .failed:
                    self.resolveWithVLC(
                        url: url,
                        reason: item.error?.localizedDescription ?? "AVFoundation failed.",
                        token: token
                    )

                case .unknown:
                    break

                @unknown default:
                    self.resolveWithVLC(
                        url: url,
                        reason: "AVFoundation returned an unknown status.",
                        token: token
                    )
                }
            }
        }
    }

    private func resolveWithAVFoundation(
        url: URL,
        player: AVPlayer,
        shouldAutoPlay: Bool,
        token: UUID
    ) {
        guard loadToken == token,
              avProbePlayer === player else {
            return
        }

        engine = .avFoundation(url: url)
    }

    // MARK: - VLC

    private func resolveWithVLC(
        url: URL,
        reason: String,
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

        engine = .vlc(url: url)
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

    private func resumeCurrentPlaybackIfNeeded(shouldAutoPlay: Bool) {
        guard shouldAutoPlay else {
            return
        }

        switch engine {
        case .avFoundation:
            break

        case .vlc,
             .loading,
             .failed:
            break
        }
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
