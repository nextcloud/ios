// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import UIKit

extension NCMedia: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        guard !imageCache.isLoadingCache,
              imageCache.allowExtensions(ext: ext) else {
            return
        }
        let cost = indexPaths.first?.row ?? 0
        let tinyMetadatas = self.dataSource.getTinyMetadatas(indexPaths: indexPaths)

        tinyMetadatas.forEach { tinyMetadata in
            if self.imageCache.getImageCache(ocId: tinyMetadata.ocId, etag: tinyMetadata.etag, ext: ext) == nil,
                let image = self.utility.getImage(ocId: tinyMetadata.ocId, etag: tinyMetadata.etag, ext: ext, userId: self.session.userId, urlBase: self.session.urlBase) {
                self.imageCache.addImageCache(ocId: tinyMetadata.ocId, etag: tinyMetadata.etag, image: image, ext: ext, cost: cost)
            }
        }
    }
}
