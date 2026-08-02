// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    func requestVLCPresentation(preparedPlayback: NCVideoVLCPreparedPlayback) {
        hasRequestedPlayback = true
        presentVLCIfSelected(preparedPlayback: preparedPlayback)
    }

    @MainActor
    func presentVLCIfSelected(preparedPlayback: NCVideoVLCPreparedPlayback) {
        guard isSelected else {
            return
        }

        guard presentedVLCURL != preparedPlayback.url else {
            return
        }

        let didPresent = NCVideoVLCPresenter.present(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: true,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onClose: closeFromFullscreenVideo,
            onPlaybackError: handleVLCPlaybackError
        )

        guard didPresent else {
            presentedVLCURL = nil
            hasRequestedPlayback = false
            isLaunchingPlayback = false
            return
        }

        presentedVLCURL = preparedPlayback.url
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
