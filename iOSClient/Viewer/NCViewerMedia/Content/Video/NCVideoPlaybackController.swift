// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import NextcloudKit

// MARK: - Video Playback Engine

/// Describes the currently rendered video playback engine.
///
/// The engine is owned by `NCVideoPlaybackController`.
/// Views only render the selected engine; they do not own AVFoundation playback resources.
/// VLC playback is rendered by a dedicated legacy-style UIKit VLC view.
enum NCVideoPlaybackEngine {
    /// No playable engine is currently ready.
    case loading

    /// Native AVFoundation playback using a resolved playable URL.
    ///
    /// The real fullscreen AVPlayer is owned by `NCVideoAVPlayerViewController`.
    case avFoundation(url: URL)

    /// VLC fallback playback using a resolved playable URL.
    ///
    /// The VLC player itself is owned by `NCVideoVLCViewerContentView`, not by this controller.
    case vlc(url: URL)

    /// Playback could not be prepared.
    case failed(message: String)
}

// MARK: - Video Playback Controller

/// Shared video playback controller used by the SwiftUI media viewer.
///
/// This controller owns AVFoundation playback resources and resolves whether
/// a video should be rendered through AVFoundation or VLC.
///
/// VLC is intentionally not owned here. The VLC renderer uses a legacy-style
/// UIKit controller with a stable `UIImageView` drawable, matching the old
/// media viewer behavior.
@MainActor
final class NCVideoPlaybackController: ObservableObject {
    static let shared = NCVideoPlaybackController()

    // MARK: - Published State

    @Published private(set) var engine: NCVideoPlaybackEngine = .loading

    // MARK: - Private State

    private var avProbePlayer: AVPlayer?
    private var avProbeItem: AVPlayerItem?
    private var statusObservation: NSKeyValueObservation?
    private var timeoutTask: Task<Void, Never>?

    private var currentOcId: String?
    private var currentEtag: String?
    private var currentURL: URL?
    private var currentFileName: String?
    private var loadToken = UUID()

    private let fallbackTimeoutMilliseconds = 1_500

    private init() { }

    // MARK: - Public API

    /// Returns whether the requested metadata and URL already match the current video.
    ///
    /// This check is used for local videos, where the playable file URL is known before
    /// loading. It prevents unnecessary reloads while still allowing the viewer to switch
    /// from a remote URL to a newly available local file URL.
    ///
    /// - Parameters:
    ///   - ocId: Nextcloud file identifier.
    ///   - etag: Metadata ETag.
    ///   - url: Expected local or remote playable URL.
    /// - Returns: True when the current loaded media matches the supplied identity and URL.
    func isCurrentVideo(
        ocId: String,
        etag: String,
        url: URL
    ) -> Bool {
        currentOcId == ocId &&
        currentEtag == etag &&
        currentURL == url
    }

    /// Returns whether the requested metadata already matches the current video.
    ///
    /// This check is used for remote videos where the resolved playback URL is not
    /// known before the resolver runs. It prevents SwiftUI rebuilds, such as rotation,
    /// from resolving and loading the same remote video again.
    ///
    /// Local videos should use the URL-based overload so the viewer can still switch
    /// from a remote URL to a newly available local file URL.
    ///
    /// - Parameters:
    ///   - ocId: Nextcloud file identifier.
    ///   - etag: Metadata ETag.
    /// - Returns: True when the current loaded media matches the supplied metadata.
    func isCurrentVideo(
        ocId: String,
        etag: String
    ) -> Bool {
        currentOcId == ocId &&
        currentEtag == etag &&
        currentURL != nil
    }

    /// Loads a video URL if it is not already loaded.
    ///
    /// Calling this method again for the same `ocId`, `etag`, and URL is idempotent.
    /// It does not stop, recreate, or restart the existing AV player. For VLC,
    /// it keeps the same engine URL so the VLC view can reuse its own controller.
    ///
    /// - Parameters:
    ///   - metadata: Video metadata used as playback identity.
    ///   - url: Local or remote playable URL.
    ///   - fileName: Original metadata file name used to detect legacy formats.
    ///   - userAgent: Optional User-Agent used by VLC for remote playback.
    ///   - httpHeaders: Optional HTTP headers used by AVFoundation for remote playback.
    ///   - shouldAutoPlay: Whether playback should start automatically.
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

            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .debug,
                message: "VIDEO controller reuse existing player ocId \(metadata.ocId)",
                consoleOnly: true
            )

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

        startFallbackTimeout(
            url: url,
            token: token
        )
    }

    /// Stops the current video only if the supplied page owns playback.
    ///
    /// - Parameter ocId: Page file identifier.
    func stopIfCurrent(ocId: String) {
        guard currentOcId == ocId else {
            return
        }

        stop()
    }

    /// Stops current playback state and releases AVFoundation resources.
    ///
    /// VLC playback is stopped by `NCVideoVLCViewerContentView` through
    /// `.ncMediaViewerStopPlayback`, because the VLC player is owned by that view.
    func stop() {
        loadToken = UUID()

        timeoutTask?.cancel()
        timeoutTask = nil

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

    /// Prepares an AVFoundation player item and observes its readiness.
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

    /// Selects AVFoundation as the active rendering engine.
    ///
    /// - Parameters:
    ///   - url: The resolved playable URL.
    ///   - player: Prepared AVFoundation player.
    ///   - shouldAutoPlay: Whether playback should start after AVFoundation becomes ready.
    ///   - token: Load token used to ignore stale callbacks.
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

        timeoutTask?.cancel()
        timeoutTask = nil

        engine = .avFoundation(url: url)

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO engine AVFoundation ready autoplay disabled requested \(shouldAutoPlay)",
            consoleOnly: true
        )
    }

    /// Starts a timeout after which VLC is selected if AVFoundation is still loading.
    private func startFallbackTimeout(
        url: URL,
        token: UUID
    ) {
        timeoutTask = Task { [weak self] in
            guard let self else {
                return
            }

            try? await Task.sleep(
                for: .milliseconds(self.fallbackTimeoutMilliseconds)
            )

            await MainActor.run {
                guard self.isCurrentLoad(
                    url: url,
                    token: token
                ) else {
                    return
                }

                if case .loading = self.engine {
                    self.resolveWithVLC(
                        url: url,
                        reason: "AVFoundation timeout.",
                        token: token
                    )
                }
            }
        }
    }

    // MARK: - VLC

    /// Selects VLC as the active rendering engine.
    ///
    /// This does not create or own the VLC player. It only exposes the URL to
    /// `NCVideoVLCViewerContentView`, which owns its legacy-style VLC controller.
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

        timeoutTask?.cancel()
        timeoutTask = nil

        statusObservation?.invalidate()
        statusObservation = nil

        avProbePlayer?.pause()
        avProbePlayer = nil
        avProbeItem = nil

        engine = .vlc(url: url)

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO engine VLC: \(reason)",
            consoleOnly: true
        )
    }

    // MARK: - State Helpers

    /// Returns whether the supplied media request is already loaded.
    private func isSameLoadedVideo(
        metadata: tableMetadata,
        url: URL
    ) -> Bool {
        currentOcId == metadata.ocId &&
        currentEtag == metadata.etag &&
        currentURL == url
    }

    /// Returns whether a callback belongs to the current load request.
    private func isCurrentLoad(
        url: URL,
        token: UUID
    ) -> Bool {
        loadToken == token && currentURL == url
    }

    /// Resumes the current AV player if requested.
    ///
    /// VLC auto-play is handled by `NCVideoVLCViewerContentView`.
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

    /// Configures the audio session for video playback.
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

    /// Returns whether a video format should bypass AVFoundation and use VLC directly.
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

    /// Resolves the best available video extension.
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

    /// Checks whether a local file exists and has a non-zero size.
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
