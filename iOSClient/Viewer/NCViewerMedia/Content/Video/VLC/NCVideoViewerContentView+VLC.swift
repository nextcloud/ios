// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    @discardableResult
    func requestVLCPresentation(preparedPlayback: NCVideoVLCPreparedPlayback) -> Bool {
        hasRequestedPlayback = true
        return presentVLCIfSelected(preparedPlayback: preparedPlayback)
    }

    @MainActor
    @discardableResult
    func presentVLCIfSelected(preparedPlayback: NCVideoVLCPreparedPlayback) -> Bool {
        guard isSelected else {
            return false
        }

        guard presentedVLCURL != preparedPlayback.url else {
            consumePendingAutoPlayIfNeeded()
            return true
        }

        let didPresent = NCVideoVLCPresenter.present(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: true,
            playbackStartReason: shouldAutoPlay ? .automaticAdvance : .userInitiated,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            playbackOptions: playbackOptions,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onPlaybackEnded: onPlayNextMedia,
            onClose: closeFromFullscreenVideo,
            onPlaybackError: handleVLCPlaybackError
        )

        guard didPresent else {
            presentedVLCURL = nil
            hasRequestedPlayback = false
            isLaunchingPlayback = false
            return false
        }

        presentedVLCURL = preparedPlayback.url
        consumePendingAutoPlayIfNeeded()
        return true
    }

    @MainActor
    func handleVLCPlaybackError() {
        NCVideoVLCPresenter.dismiss {
            showPlaybackError()
        }
    }

    @MainActor
    func goToPreviousPageFromVLC() {
        NCVideoVLCPresenter.dismiss {
            resetPlaybackPresentationState()
            onPreviousPage?()
        }
    }

    @MainActor
    func goToNextPageFromVLC() {
        NCVideoVLCPresenter.dismiss {
            resetPlaybackPresentationState()
            onNextPage?()
        }
    }
}
