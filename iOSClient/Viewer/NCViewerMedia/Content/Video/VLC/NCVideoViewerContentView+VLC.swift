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

        presentedVLCURL = preparedPlayback.url

        NCVideoVLCPresenter.present(
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
