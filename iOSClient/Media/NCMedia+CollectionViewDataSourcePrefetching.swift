// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import UIKit

extension NCMedia: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        let compactMetadatas = self.dataSource.getCompactMetadatas(indexPaths: indexPaths)

        compactMetadatas.forEach { compactMetadata in
            if self.imageCache.getImageCache(ocId: compactMetadata.ocId, etag: compactMetadata.etag, ext: ext) == nil,
                let image = self.utility.getImage(ocId: compactMetadata.ocId, etag: compactMetadata.etag, ext: ext, userId: self.session.userId, urlBase: self.session.urlBase) {
                self.imageCache.addImageCache(ocId: compactMetadata.ocId, etag: compactMetadata.etag, image: image, ext: ext)
            }
        }
    }
}
