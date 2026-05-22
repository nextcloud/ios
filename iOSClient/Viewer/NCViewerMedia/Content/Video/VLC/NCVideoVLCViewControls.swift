import UIKit
import MobileVLCKit

// MARK: - Playback Controls

extension NCVideoVLCViewController {
    /// Seeks ten seconds backward in the current VLC media.
    @objc
    func seekBackwardTapped() {
        showControls(animated: true)
        scheduleControlsHide()
        seek(byMilliseconds: -10_000)
    }

    /// Toggles VLC playback.
    @objc
    func playPauseTapped() {
        showControls(animated: true)

        if mediaPlayer.isPlaying {
            mediaPlayer.pause()
            showControls(animated: false)
            stopControlsHideTimer()
        } else {
            mediaPlayer.play()
        }

        updatePlayPauseButton()
        updateProgressControls()
    }

    /// Seeks ten seconds forward in the current VLC media.
    @objc
    func seekForwardTapped() {
        showControls(animated: true)
        scheduleControlsHide()
        seek(byMilliseconds: 10_000)
    }

    /// Moves the current VLC playback time by a relative millisecond offset.
    ///
    /// - Parameter deltaMilliseconds: Relative seek offset in milliseconds.
    func seek(byMilliseconds deltaMilliseconds: Int32) {
        let duration = mediaPlayer.media?.length.intValue ?? 0
        guard duration > 0 else {
            return
        }

        let currentTime = mediaPlayer.time.intValue
        let targetTime = max(
            0,
            min(
                Int(duration),
                Int(currentTime + deltaMilliseconds)
            )
        )

        mediaPlayer.time = VLCTime(int: Int32(targetTime))
        updateProgressControls()
    }

    /// Updates the play/pause button icon from the current VLC playback state.
    func updatePlayPauseButton() {
        controlsView.updatePlayPauseButton(isPlaying: mediaPlayer.isPlaying)
    }

    /// Starts periodic progress updates.
    func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.35,
            repeats: true
        ) { [weak self] _ in
            self?.updateProgressControls()
        }
    }

    /// Stops periodic progress updates.
    func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Updates slider and time labels from the current VLC playback position.
    func updateProgressControls() {
        guard !isScrubbing else {
            return
        }

        let position = max(0, min(1, mediaPlayer.position))
        updateProgressLabels(position: position)
        updatePlayPauseButton()
    }

    /// Updates elapsed and remaining time labels.
    ///
    /// - Parameter position: Normalized playback position between 0 and 1.
    func updateProgressLabels(position: Float) {
        let duration = mediaPlayer.media?.length.intValue ?? 0
        let elapsed = Int(Float(duration) * position)
        let remaining = max(0, Int(duration) - elapsed)

        controlsView.updateProgress(
            progress: position,
            elapsedText: formatPlaybackTime(milliseconds: elapsed),
            remainingText: "−" + formatPlaybackTime(milliseconds: remaining)
        )
    }

    /// Formats milliseconds as a compact playback time.
    ///
    /// - Parameter milliseconds: Time value in milliseconds.
    /// - Returns: Formatted time string.
    func formatPlaybackTime(milliseconds: Int) -> String {
        let totalSeconds = max(0, milliseconds / 1000)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Controls Visibility

extension NCVideoVLCViewController {
    /// Shows the VLC playback controls.
    ///
    /// - Parameter animated: Whether the visibility change should be animated.
    internal func showControls(animated: Bool) {
        setNavigationBarVisible(
            true,
            animated: animated
        )
        controlsVisible = true
        setControlsVisible(true, animated: animated)
    }

    /// Hides the VLC playback controls.
    ///
    /// - Parameter animated: Whether the visibility change should be animated.
    internal func hideControls(animated: Bool) {
        guard !shouldKeepControlsVisible else {
            showControls(animated: false)
            stopControlsHideTimer()
            return
        }

        setNavigationBarVisible(
            false,
            animated: animated
        )
        controlsVisible = false
        stopControlsHideTimer()
        setControlsVisible(false, animated: animated)
    }

    /// Applies the current controls visibility to the control views.
    ///
    /// - Parameters:
    ///   - visible: Whether controls should be visible.
    ///   - animated: Whether the visibility change should be animated.
    internal func setControlsVisible(_ visible: Bool, animated: Bool) {
        let changes = {
            self.controlsView.alpha = visible ? 1 : 0
        }

        let completion: (Bool) -> Void = { _ in
            self.controlsView.isHidden = !visible
        }

        if visible {
            controlsView.isHidden = false
        }

        guard animated else {
            changes()
            completion(true)
            return
        }

        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseInOut],
            animations: changes,
            completion: completion
        )
    }

    /// Schedules automatic hiding for the VLC playback controls.
    internal func scheduleControlsHide() {
        stopControlsHideTimer()

        guard !shouldKeepControlsVisible else {
            return
        }

        guard controlsVisible else {
            return
        }

        controlsHideTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self,
                      !self.isScrubbing else {
                    return
                }

                self.hideControls(animated: true)
            }
        }
    }

    /// Stops the automatic controls hide timer.
    internal func stopControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }
}

// MARK: - Shared Controls Delegate

extension NCVideoVLCViewController: NCVideoControlsViewDelegate {
    /// Handles the shared controls backward seek action.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapSeekBackward(_ controlsView: NCVideoControlsView) {
        seekBackwardTapped()
    }

    /// Handles the shared controls play/pause action.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapPlayPause(_ controlsView: NCVideoControlsView) {
        playPauseTapped()
    }

    /// Handles the shared controls forward seek action.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapSeekForward(_ controlsView: NCVideoControlsView) {
        seekForwardTapped()
    }

    /// Handles the Picture in Picture action from the shared controls view.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapPictureInPicture(_ controlsView: NCVideoControlsView) {
        // VLC does not expose Picture in Picture controls.
    }

    /// Handles the beginning of slider scrubbing from the shared controls view.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidBeginScrubbing(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        isScrubbing = true
    }

    /// Handles the VLC subtitle track action from the shared controls view.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapSubtitle(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()
    }

    /// Handles the VLC audio track action from the shared controls view.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapAudio(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()
    }

    /// Handles the external subtitle import action from the shared controls view.
    ///
    /// - Parameter controlsView: Shared controls view that emitted the action.
    func videoControlsDidTapAddExternalSubtitle(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        presentExternalSubtitlePicker()
    }

    /// Handles VLC subtitle track selection from the SwiftUI controls menu.
    ///
    /// - Parameters:
    ///   - controlsView: Shared controls view that emitted the action.
    ///   - index: VLC subtitle track index selected by the user.
    func videoControls(_ controlsView: NCVideoControlsView, didSelectSubtitleTrackIndex index: Int32) {
        showControls(animated: true)
        stopControlsHideTimer()
        selectSubtitleTrack(index: index)
    }

    /// Handles VLC audio track selection from the SwiftUI controls menu.
    ///
    /// - Parameters:
    ///   - controlsView: Shared controls view that emitted the action.
    ///   - index: VLC audio track index selected by the user.
    func videoControls(_ controlsView: NCVideoControlsView, didSelectAudioTrackIndex index: Int32) {
        showControls(animated: true)
        stopControlsHideTimer()
        selectAudioTrack(index: index)
    }

    /// Updates VLC time labels while scrubbing from the shared controls view.
    ///
    /// - Parameters:
    ///   - controlsView: Shared controls view that emitted the action.
    ///   - progress: Normalized target progress between 0 and 1.
    func videoControls(_ controlsView: NCVideoControlsView, didScrubTo progress: Float) {
        updateProgressLabels(position: progress)
    }

    /// Applies the selected VLC playback position after scrubbing ends.
    ///
    /// - Parameters:
    ///   - controlsView: Shared controls view that emitted the action.
    ///   - progress: Normalized target progress between 0 and 1.
    func videoControlsDidEndScrubbing(_ controlsView: NCVideoControlsView, progress: Float) {
        mediaPlayer.position = progress
        isScrubbing = false
        updateProgressControls()
        scheduleControlsHide()
    }
}
