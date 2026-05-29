// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    func requestAVPlayerPresentation(url: URL) {
        hasRequestedPlayback = true
        presentAVPlayerIfSelected(url: url)
    }

    @MainActor
    func presentAVPlayerIfSelected(url: URL) {
        guard isSelected else {
            return
        }

        guard presentedAVPlayerURL != url else {
            return
        }

        presentedAVPlayerURL = url

        NCVideoAVPlayerPresenter.present(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            shouldAutoPlay: true,
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
