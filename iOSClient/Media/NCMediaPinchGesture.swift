//
//  MediaZoom.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 13/09/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

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

                    if let layoutForView = self.database.getLayoutForView(account: self.session.account, key: self.global.layoutViewMedia, serverUrl: "") {
                        layoutForView.columnPhoto = self.numberOfColumns
                        self.database.setLayoutForView(layoutForView: layoutForView)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.transitionColumns = false
            }
        }

        switch gestureRecognizer.state {
        case .began:
            networkRemoveAll(nil)
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
