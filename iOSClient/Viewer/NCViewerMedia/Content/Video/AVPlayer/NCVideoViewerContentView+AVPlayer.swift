// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    @discardableResult
    func requestAVPlayerPresentation(preparedPlayback: NCVideoAVPreparedPlayback) -> Bool {
        hasRequestedPlayback = true
        return presentAVPlayerIfSelected(preparedPlayback: preparedPlayback)
    }

    @MainActor
    @discardableResult
    func presentAVPlayerIfSelected(preparedPlayback: NCVideoAVPreparedPlayback) -> Bool {
        guard isSelected else {
            return false
        }

        guard presentedAVPlayerURL != preparedPlayback.url else {
            consumePendingAutoPlayIfNeeded()
            return true
        }

        let didPresent = NCVideoAVPlayerPresenter.present(
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
            onPrevious: goToPreviousPageFromAVPlayer,
            onNext: goToNextPageFromAVPlayer,
            onPlaybackEnded: onPlayNextMedia,
            onClose: closeFromFullscreenVideo,
            onPlaybackError: handleAVPlayerPlaybackError
        )

        guard didPresent else {
            presentedAVPlayerURL = nil
            hasRequestedPlayback = false
            isLaunchingPlayback = false
            return false
        }

        presentedAVPlayerURL = preparedPlayback.url
        consumePendingAutoPlayIfNeeded()
        return true
    }

    @MainActor
    func handleAVPlayerPlaybackError() {
        NCVideoAVPlayerPresenter.dismiss {
            showPlaybackError()
        }
    }

    @MainActor
    func goToPreviousPageFromAVPlayer() {
        NCVideoAVPlayerPresenter.dismiss {
            resetPlaybackPresentationState()
            onPreviousPage?()
        }
    }

    @MainActor
    func goToNextPageFromAVPlayer() {
        NCVideoAVPlayerPresenter.dismiss {
            resetPlaybackPresentationState()
            onNextPage?()
        }
    }
}
