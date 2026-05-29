// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCVideoViewerContentView {
    @MainActor
    func requestVLCPresentation(url: URL) {
        hasRequestedPlayback = true
        presentVLCIfSelected(url: url)
    }

    @MainActor
    func presentVLCIfSelected(url: URL) {
        guard isSelected else {
            return
        }

        guard presentedVLCURL != url else {
            return
        }

        presentedVLCURL = url

        NCVideoVLCPresenter.present(
            metadata: metadata,
            url: url,
            userAgent: userAgent,
            shouldAutoPlay: true,
            isChromeHidden: isChromeHidden,
            contextMenuController: contextMenuController,
            canGoPrevious: canGoPrevious,
            canGoNext: canGoNext,
            onPrevious: goToPreviousPageFromVLC,
            onNext: goToNextPageFromVLC,
            onClose: closeFromFullscreenVideo
        )
    }

    @MainActor
    func goToPreviousPageFromVLC() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoVLCPresenter.dismiss()
            },
            changePage: {
                onPreviousPage?()
            }
        )
    }

    @MainActor
    func goToNextPageFromVLC() {
        performFullscreenPageTransition(
            dismissPlayer: {
                NCVideoVLCPresenter.dismiss()
            },
            changePage: {
                onNextPage?()
            }
        )
    }
}
