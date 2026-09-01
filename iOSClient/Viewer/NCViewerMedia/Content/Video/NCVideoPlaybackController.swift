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
    private var avProbeTask: Task<Void, Never>?
    private var avProbeTimeoutTask: Task<Void, Never>?

    private var currentOcId: String?
    private var currentEtag: String?
    private var currentURL: URL?
    private var currentUserAgent: String?
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
        currentUserAgent = userAgent
        engine = .loading

        if url.isFileURL,
           !isValidLocalFile(url: url) {
            engine = .failed(message: "")
            return
        }

        configureAudioSession()

        if NCPreferences().alwaysUseVLCForVideo(account: metadata.account, ocId: metadata.ocId) {
            resolveWithVLC(
                url: url,
                userAgent: userAgent,
                token: token
            )
            return
        }

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
            url: url,
            userAgent: userAgent,
            httpHeaders: url.isFileURL ? [:] : httpHeaders,
            token: token
        )
    }

    // Changes only the prepared engine. Playback still starts from the cover.
    func switchToVLC() {
        guard let currentURL else {
            return
        }

        resolveWithVLC(
            url: currentURL,
            userAgent: currentUserAgent,
            token: loadToken
        )
    }

    func retryAVFoundation() {
        guard let currentURL else {
            return
        }

        let token = UUID()
        loadToken = token

        cancelAVProbeTasks()

        avProbePlayer?.pause()
        avProbePlayer = nil
        avProbeItem = nil

        engine = .loading

        var httpHeaders: [String: String] = [:]

        if let currentUserAgent,
           !currentUserAgent.isEmpty,
           !currentURL.isFileURL {
            httpHeaders["User-Agent"] = currentUserAgent
        }

        prepareAVFoundation(
            url: currentURL,
            userAgent: currentUserAgent,
            httpHeaders: httpHeaders,
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

        cancelAVProbeTasks()

        avProbePlayer?.pause()
        avProbePlayer = nil
        avProbeItem = nil

        currentOcId = nil
        currentEtag = nil
        currentURL = nil
        currentUserAgent = nil
        engine = .loading
    }

    // MARK: - AVFoundation

    private func prepareAVFoundation(
        url: URL,
        userAgent: String?,
        httpHeaders: [String: String],
        token: UUID
    ) {
        cancelAVProbeTasks()

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

        avProbeTask = Task { [weak self] in
            do {
                let isPlayable = try await asset.load(.isPlayable)

                guard !Task.isCancelled,
                      let self,
                      self.isCurrentLoad(
                        url: url,
                        token: token
                      ) else {
                    return
                }

                if isPlayable {
                    self.resolveWithAVFoundation(
                        url: url,
                        player: player,
                        item: item,
                        token: token
                    )
                } else {
                    self.resolveWithVLC(
                        url: url,
                        userAgent: userAgent,
                        token: token
                    )
                }
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.isCurrentLoad(
                        url: url,
                        token: token
                      ) else {
                    return
                }

                self.resolveWithVLC(
                    url: url,
                    userAgent: userAgent,
                    token: token
                )
            }
        }

        avProbeTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(8))
            } catch {
                return
            }

            guard !Task.isCancelled,
                  let self,
                  self.isCurrentLoad(
                    url: url,
                    token: token
                  ) else {
                return
            }

            self.resolveWithVLC(
                url: url,
                userAgent: userAgent,
                token: token
            )
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

        cancelAVProbeTasks()

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

        cancelAVProbeTasks()

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

    private func cancelAVProbeTasks() {
        avProbeTask?.cancel()
        avProbeTask = nil

        avProbeTimeoutTask?.cancel()
        avProbeTimeoutTask = nil
    }

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
