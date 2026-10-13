// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import UIKit

// MARK: - Playback Controls

extension NCVideoAVPlayerViewController {
    private func seek(bySeconds seconds: Double) {
        guard let duration = player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            return
        }

        let currentTime = player.currentTime().seconds
        let targetSeconds = max(
            0,
            min(duration, currentTime + seconds)
        )

        let targetTime = CMTime(
            seconds: targetSeconds,
            preferredTimescale: 600
        )

        player.seek(
            to: targetTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgressControls()
                self?.scheduleControlsHide()
            }
        }
    }
}

// MARK: - Controls Visibility

extension NCVideoAVPlayerViewController {

    func showControls(animated: Bool) {
        guard !isPictureInPictureActive else {
            updateViewerBackground(isChromeHidden: true)
            setControlsVisible(
                false,
                animated: false
            )
            setNavigationBarVisible(
                false,
                animated: false
            )
            return
        }

        updateViewerBackground(isChromeHidden: false)

        setNavigationBarVisible(
            true,
            animated: animated
        )
        setControlsVisible(
            true,
            animated: animated
        )
    }

    func hideControls(animated: Bool) {
        guard !shouldKeepControlsVisible else {
            showControls(animated: false)
            stopControlsHideTimer()
            return
        }

        updateViewerBackground(isChromeHidden: true)

        setNavigationBarVisible(
            false,
            animated: animated
        )
        setControlsVisible(
            false,
            animated: animated
        )
    }

    private func setControlsVisible(_ visible: Bool, animated: Bool) {
        stopControlsHideTimer()

        controlsVisible = visible
        let controlsView = self.controlsView
        controlsView.isUserInteractionEnabled = visible

        if visible {
            controlsView.isHidden = false
        }

        let updates = {
            controlsView.alpha = visible ? 1 : 0
        }

        let completion: (Bool) -> Void = { _ in
            if !self.controlsVisible {
                controlsView.isHidden = true
            }
        }

        if animated {
            UIView.animate(
                withDuration: 0.18,
                animations: updates,
                completion: completion
            )
        } else {
            updates()
            completion(true)
        }
    }

    func scheduleControlsHide() {
        stopControlsHideTimer()

        guard !isPictureInPictureActive else {
            return
        }

        guard !shouldKeepControlsVisible else {
            return
        }

        guard controlsVisible else {
            return
        }

        controlsHideTimer = Timer.scheduledTimer(
            withTimeInterval: 3,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      !self.playbackPresentationContext.isSeeking else {
                    return
                }

                self.hideControls(animated: true)
            }
        }
    }

    func stopControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }
}

// MARK: - Shared Controls Delegate

extension NCVideoAVPlayerViewController: NCVideoControlsViewDelegate {

    func videoControlsDidTapSeekBackward(_ controlsView: any NCVideoPlaybackControls) {
        seek(bySeconds: -10)
    }

    func videoControlsDidTapPlayPause(_ controlsView: any NCVideoPlaybackControls) {
        if isPlaybackRequested {
            isPlaybackRequested = false
            player.pause()
            updatePlayPauseButton()
            stopControlsHideTimer()
            return
        }

        switch player.timeControlStatus {
        case .playing:
            isPlaybackRequested = false
            player.pause()

        case .paused,
             .waitingToPlayAtSpecifiedRate:
            if let duration = player.currentItem?.duration.seconds,
               duration.isFinite,
               player.currentTime().seconds >= duration - 0.2 {
                player.seek(to: .zero)
            }

            playWhenAudioSessionIsReady()

        @unknown default:
            playWhenAudioSessionIsReady()
        }

        updatePlayPauseButton()
        scheduleControlsHide()
    }

    func videoControlsDidTapSeekForward(_ controlsView: any NCVideoPlaybackControls) {
        seek(bySeconds: 10)
    }

    func videoControlsDidToggleRepeat(_ controlsView: any NCVideoPlaybackControls) {
        playbackOptions.toggleRepeat()
        updatePlaybackOptionsControls()
        scheduleControlsHide()
    }

    func videoControlsDidToggleAutoAdvance(_ controlsView: any NCVideoPlaybackControls) {
        playbackOptions.toggleAutoAdvance()
        updatePlaybackOptionsControls()
        scheduleControlsHide()
    }

    func videoControlsDidTapPictureInPicture(_ controlsView: any NCVideoPlaybackControls) {
        togglePictureInPicture()
    }

    func videoControlsDidBeginScrubbing(_ controlsView: any NCVideoPlaybackControls) {
        playbackPresentationContext.beginSeeking()
        stopControlsHideTimer()
    }

    func videoControls(_ controlsView: any NCVideoPlaybackControls, didScrubTo progress: Float) {
        guard let duration = player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            return
        }

        let targetTime = duration * Double(progress)

        controlsView.updateProgress(
            progress: progress,
            elapsedText: Self.formatTime(targetTime),
            remainingText: "−\(Self.formatTime(max(0, duration - targetTime)))"
        )
    }

    func videoControlsDidEndScrubbing(_ controlsView: any NCVideoPlaybackControls, progress: Float) {
        guard let duration = player.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            playbackPresentationContext.finishSeeking()
            hideControls(animated: true)
            return
        }

        let targetTime = CMTime(
            seconds: duration * Double(progress),
            preferredTimescale: 600
        )

        player.seek(
            to: targetTime,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playbackPresentationContext.finishSeeking()
                self?.updateProgressControls()
                self?.hideControls(animated: true)
            }
        }
    }
}
