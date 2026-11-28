// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Simon St-Michel
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MediaPlayer
import UIKit

/// Connects the audio viewer to the system "Now Playing" surfaces: Lock Screen,
/// Control Center, Dynamic Island, headphone/car buttons and AirPlay receivers.
///
/// iOS shows these controls only when the app does both of the following:
/// 1. publishes a description of the current item in `MPNowPlayingInfoCenter`;
/// 2. registers at least one handler in `MPRemoteCommandCenter`.
///
/// The viewer can keep several `NCAudioViewerModel` instances alive at once
/// (one per audio page), but only the model that started playing *owns* the
/// Now Playing session. Calls from any other model are ignored, so preparing or
/// stopping a neighboring page never clears the controls of the playing one.
@MainActor
final class NCAudioNowPlayingController {
    static let shared = NCAudioNowPlayingController()

    /// Matches the −10/+10 buttons of the in-app audio controls.
    static let skipInterval: Double = 10

    private weak var owner: NCAudioViewerModel?
    private var commandTargets: [(command: MPRemoteCommand, target: Any)] = []

    private init() { }

    // MARK: - Session ownership

    /// Makes `model` the owner of the Now Playing session and enables the remote commands.
    func activate(_ model: NCAudioViewerModel) {
        owner = model
        registerRemoteCommandsIfNeeded()
    }

    /// Publishes the current playback state. Ignored unless `model` owns the session.
    func update(_ model: NCAudioViewerModel, metadata: NCAudioNowPlayingMetadata, duration: Double, elapsedTime: Double, isPlaying: Bool) {
        guard owner === model else {
            return
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = Self.nowPlayingInfo(
            metadata: metadata,
            duration: duration,
            elapsedTime: elapsedTime,
            isPlaying: isPlaying
        )
    }

    /// Removes the Lock Screen and Control Center controls. Ignored unless `model` owns the session.
    func deactivate(_ model: NCAudioViewerModel) {
        guard owner === model else {
            return
        }

        owner = nil
        unregisterRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Now Playing info

    /// Builds the dictionary expected by `MPNowPlayingInfoCenter`.
    ///
    /// The system advances the displayed position on its own from the elapsed time
    /// and the playback rate, so this only needs to be published when the state
    /// changes (play, pause, seek, new duration or metadata), not on every tick.
    nonisolated static func nowPlayingInfo(metadata: NCAudioNowPlayingMetadata, duration: Double, elapsedTime: Double, isPlaying: Bool) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: metadata.title,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime.isFinite ? max(0, elapsedTime) : 0,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let artist = metadata.artist {
            info[MPMediaItemPropertyArtist] = artist
        }

        if let albumTitle = metadata.albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = albumTitle
        }

        if let artworkData = metadata.artworkData,
           let artwork = artwork(from: artworkData) {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        return info
    }

    /// `nonisolated` on purpose: the system calls the artwork request handler on a
    /// background queue. A closure created inside a `@MainActor` method would be
    /// main-actor isolated and trap under Swift 6 when called from that queue.
    nonisolated private static func artwork(from data: Data) -> MPMediaItemArtwork? {
        guard let image = UIImage(data: data) else {
            return nil
        }

        return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }

    // MARK: - Remote commands

    private func registerRemoteCommandsIfNeeded() {
        guard commandTargets.isEmpty else {
            return
        }

        let center = MPRemoteCommandCenter.shared()

        addTarget(center.playCommand) { model, _ in
            model.play()
            return .success
        }

        addTarget(center.pauseCommand) { model, _ in
            model.pause()
            return .success
        }

        // Sent by wired/Bluetooth headphones and some car systems.
        addTarget(center.togglePlayPauseCommand) { model, _ in
            model.togglePlayback()
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        addTarget(center.skipBackwardCommand) { model, event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval
            model.seek(to: model.currentTime - interval)
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [NSNumber(value: Self.skipInterval)]
        addTarget(center.skipForwardCommand) { model, event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? Self.skipInterval
            model.seek(to: model.currentTime + interval)
            return .success
        }

        // Dragging the progress bar on the Lock Screen or in Control Center.
        addTarget(center.changePlaybackPositionCommand) { model, event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            model.seek(to: event.positionTime)
            return .success
        }
    }

    private func addTarget(
        _ command: MPRemoteCommand,
        handler: @escaping @MainActor (NCAudioViewerModel, MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        command.isEnabled = true

        // MediaPlayer calls remote command handlers on the main thread.
        let target = command.addTarget { [weak self] event in
            MainActor.assumeIsolated {
                guard let model = self?.owner else {
                    return .noActionableNowPlayingItem
                }

                return handler(model, event)
            }
        }

        commandTargets.append((command, target))
    }

    /// Removing the handlers is enough: a command without handlers is hidden by the system.
    /// `isEnabled` is left untouched because the command center is shared with the video players.
    private func unregisterRemoteCommands() {
        for (command, target) in commandTargets {
            command.removeTarget(target)
        }

        commandTargets.removeAll()
    }
}
