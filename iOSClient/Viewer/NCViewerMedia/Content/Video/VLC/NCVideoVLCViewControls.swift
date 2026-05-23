import UIKit
import MobileVLCKit

// MARK: - Playback Controls

extension NCVideoVLCViewController {
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

    func updatePlayPauseButton() {
        controlsView.updatePlayPauseButton(isPlaying: mediaPlayer.isPlaying)
    }

    func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(
            withTimeInterval: 0.35,
            repeats: true
        ) { [weak self] _ in
            self?.updateProgressControls()
        }
    }

    func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func updateProgressControls() {
        guard !isScrubbing else {
            return
        }

        let position = max(0, min(1, mediaPlayer.position))
        updateProgressLabels(position: position)
        updatePlayPauseButton()
    }

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
    internal func showControls(animated: Bool) {
        setNavigationBarVisible(
            true,
            animated: animated
        )
        controlsVisible = true
        setControlsVisible(true, animated: animated)
    }

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

    internal func stopControlsHideTimer() {
        controlsHideTimer?.invalidate()
        controlsHideTimer = nil
    }
}

// MARK: - Shared Controls Delegate
extension NCVideoVLCViewController: NCVideoControlsViewDelegate {
    func videoControlsDidTapSeekBackward(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        scheduleControlsHide()
        seek(byMilliseconds: -10_000)
    }

    func videoControlsDidTapPlayPause(_ controlsView: NCVideoControlsView) {
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

    func videoControlsDidTapSeekForward(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        scheduleControlsHide()
        seek(byMilliseconds: 10_000)
    }

    func videoControlsDidBeginScrubbing(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        isScrubbing = true
    }

    func videoControlsDidTapSubtitle(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()
    }

    func videoControlsDidTapAudio(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()
    }

    func videoControlsDidTapAddExternalSubtitle(_ controlsView: NCVideoControlsView) {
        showControls(animated: true)
        stopControlsHideTimer()
        presentExternalSubtitlePicker()
    }

    func videoControls(_ controlsView: NCVideoControlsView, didSelectSubtitleTrackIndex index: Int32) {
        showControls(animated: true)
        stopControlsHideTimer()
        selectSubtitleTrack(index: index)
    }

    func videoControls(_ controlsView: NCVideoControlsView, didSelectAudioTrackIndex index: Int32) {
        showControls(animated: true)
        stopControlsHideTimer()
        selectAudioTrack(index: index)
    }

    func videoControls(_ controlsView: NCVideoControlsView, didScrubTo progress: Float) {
        updateProgressLabels(position: progress)
    }

    func videoControlsDidEndScrubbing(_ controlsView: NCVideoControlsView, progress: Float) {
        mediaPlayer.position = progress
        isScrubbing = false
        updateProgressControls()
        scheduleControlsHide()
    }
}
