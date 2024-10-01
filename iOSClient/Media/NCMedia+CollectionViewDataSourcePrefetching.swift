//
//  NCMedia+CollectionViewDataSourcePrefetching.swift
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

extension NCMedia: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        guard !imageCache.isLoadingCache,
              imageCache.allowExtensions(ext: ext)
        else { return }
        let cost = indexPaths.first?.row ?? 0

        DispatchQueue.global().async {
            let metadatas = self.dataSource.getMetadatas(indexPaths: indexPaths)
            metadatas.forEach { metadata in
                if self.imageCache.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) == nil,
                   let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext, cost: cost)
                }
            }
        }
    }
}
