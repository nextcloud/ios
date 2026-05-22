// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCCollectionViewCommon {
    /// Returns the transition source for a media item in the collection view.
    ///
    /// If the target cell is visible, the transition uses the real preview image view frame.
    /// If the target cell is not materialized yet, the transition falls back to the
    /// collection view layout attributes so the closing animation can still target
    /// the correct item position.
    ///
    /// - Parameter ocId: Nextcloud file identifier of the media item.
    /// - Returns: Transition source if the item can be resolved.
    func viewerTransitionSource(for ocId: String) -> NCViewerTransitionSource? {
        guard let indexPath = dataSource.getIndexPathMetadata(ocId: ocId),
              let window = collectionView.window else {
            return nil
        }

        collectionView.layoutIfNeeded()

        if collectionView.cellForItem(at: indexPath) == nil {
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: false
            )

            collectionView.layoutIfNeeded()
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? NCCellMainProtocol,
           let imageView = cell.previewImg,
           let image = imageView.image {
            let sourceFrame = imageView.convert(
                imageView.bounds,
                to: window
            )

            return NCViewerTransitionSource(
                image: image,
                sourceFrame: sourceFrame,
                cornerRadius: imageView.layer.cornerRadius
            )
        }

        guard let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return nil
        }

        let sourceFrame = collectionView.convert(
            attributes.frame,
            to: window
        )

        return NCViewerTransitionSource(
            image: UIImage(),
            sourceFrame: sourceFrame,
            cornerRadius: 6
        )
    }

    /// Briefly highlights the collection view cell associated with the given ocId.
    ///
    /// If the target item is not currently visible, the collection view scrolls to it first.
    /// The highlight is intentionally lightweight and temporary.
    @MainActor
    func blinkItem(ocId: String) {
        guard let indexPath = dataSource.getIndexPathMetadata(ocId: ocId) else {
            return
        }

        collectionView.layoutIfNeeded()

        if collectionView.cellForItem(at: indexPath) == nil {
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: false
            )

            view.layoutIfNeeded()
            collectionView.layoutIfNeeded()
        }

        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }

        blink(view: cell.contentView)
    }

    /// Applies a short blink animation to the provided view.
    ///
    /// - Parameter view: View that should be visually highlighted.
    private func blink(view: UIView) {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.22)
        overlay.layer.cornerRadius = view.layer.cornerRadius
        overlay.isUserInteractionEnabled = false
        overlay.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        view.addSubview(overlay)

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            overlay.alpha = 0.0
        } completion: { _ in
            overlay.removeFromSuperview()
        }
    }

}
