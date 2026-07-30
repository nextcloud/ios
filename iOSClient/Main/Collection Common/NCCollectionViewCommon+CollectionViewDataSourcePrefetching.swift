// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension NCCollectionViewCommon: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        /*
        let ext = global.getSizeExtension(column: self.numberOfColumns)
        guard !isSearchingMode else {
            return
        }

        for indexPath in indexPaths {
            guard let metadata = dataSource.getMetadata(indexPath: indexPath) else {
                continue
            }

            // PREVIEW IMAGE
            if let metadata = dataSource.getMetadata(indexPath: indexPath),
               imageCache.getImageCache(ocId: metadata.ocId, etag: metadata.etag, ext: ext) == nil,
               let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: ext, userId: metadata.userId, urlBase: metadata.urlBase) {
                imageCache.addImageCache(ocId: metadata.ocId, etag: metadata.etag, image: image, ext: ext)
            }

            // AVATAR
            if !metadata.ownerId.isEmpty, metadata.ownerId != metadata.userId {
                let fileName = NCSession.shared.getFileName(urlBase: metadata.urlBase, user: metadata.ownerId)
                let fileNameLocalPath = utilityFileSystem.createServerUrl(serverUrl: utilityFileSystem.directoryUserData, fileName: fileName)

                if imageCache.getImageCache(key: fileName) == nil,
                   let image = UIImage(contentsOfFile: fileNameLocalPath) {
                    imageCache.addImageCache(image: image, key: fileName)
                }
            }
        }
        */
    }
}
