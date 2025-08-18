// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCMedia {
    @objc func handlePinchGesture(_ gestureRecognizer: UIPinchGestureRecognizer) {
        func updateNumberOfColumns() {
            let originalColumns = numberOfColumns
            transitionColumns = true

            if currentScale < 1 && numberOfColumns < maxColumns {
                numberOfColumns += 1
            } else if currentScale > 1 && numberOfColumns > 1 {
                numberOfColumns -= 1
            }

            if originalColumns != numberOfColumns {

                self.collectionView.transform = .identity
                self.currentScale = 1.0

                UIView.transition(with: self.collectionView, duration: 0.20, options: .transitionCrossDissolve) {

                    self.collectionView.reloadData()
                    self.collectionView.collectionViewLayout.invalidateLayout()

                } completion: { _ in

                    self.database.updatePhotoLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "") { layout in
                        layout.columnPhoto = self.numberOfColumns
                    }

                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.transitionColumns = false
            }
        }

        switch gestureRecognizer.state {
        case .began:
            Task {
                await self.networkRemoveAll()
            }
            lastScale = gestureRecognizer.scale
            lastNumberOfColumns = numberOfColumns
        case .changed:
            guard !transitionColumns else {
                return
            }
            let scale = gestureRecognizer.scale
            let scaleChange = scale / lastScale

            currentScale *= scaleChange
            currentScale = max(0.5, min(currentScale, 2.0))

            updateNumberOfColumns()

            if numberOfColumns > 1 && numberOfColumns < maxColumns {
                collectionView.transform = CGAffineTransform(scaleX: currentScale, y: currentScale)
            }

            lastScale = scale
        case .ended:
            UIView.animate(withDuration: 0.30) {
                self.currentScale = 1.0
                self.collectionView.transform = .identity
                self.setTitleDate()
            }
        default:
            break
        }
    }
}
