// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    func requestAVPlayerPresentation(preparedPlayback: NCVideoAVPreparedPlayback) {
        hasRequestedPlayback = true
        presentAVPlayerIfSelected(preparedPlayback: preparedPlayback)
    }

    @MainActor
    func presentAVPlayerIfSelected(preparedPlayback: NCVideoAVPreparedPlayback) {
        guard isSelected else {
            return
        }

        guard presentedAVPlayerURL != preparedPlayback.url else {
            return
        }

        presentedAVPlayerURL = preparedPlayback.url

        NCVideoAVPlayerPresenter.present(
            metadata: metadata,
            preparedPlayback: preparedPlayback,
            userAgent: userAgent,
            shouldAutoPlayOnStart: true,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromAVPlayer,
            onNext: goToNextPageFromAVPlayer,
            onClose: closeFromFullscreenVideo
        )
    }

    @MainActor
    func goToPreviousPageFromAVPlayer() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoAVPlayerPresenter.dismiss()
            },
            changePage: {
                onPreviousPage?()
            }
        )
    }

    @MainActor
    func goToNextPageFromAVPlayer() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoAVPlayerPresenter.dismiss()
            },
            changePage: {
                onNextPage?()
            }
        )
    }
}
