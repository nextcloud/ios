//
//  NCCollectionViewCommon+CollectionViewDataSourcePrefetching.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/09/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension NCCollectionViewCommon: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard !isSearchingMode else { return }
        let ext = global.getSizeExtension(width: self.sizeImage.width)
        let metadatas = self.dataSource.getMetadatas(indexPaths: indexPaths)

        DispatchQueue.global(qos: .userInteractive).async {
            for metadata in metadatas where metadata.isImageOrVideo {
                if self.imageCache.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) == nil,
                   let image = self.utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext) {
                    self.imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext)
                }
            }
        }
    }
}
