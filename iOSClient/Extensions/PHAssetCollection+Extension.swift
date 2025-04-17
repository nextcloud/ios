// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Photos

extension PHAssetCollection {
    public static func == (lhs: PHAssetCollection, rhs: PHAssetCollection) -> Bool {
        return lhs.localIdentifier == rhs.localIdentifier || lhs.assetCount == rhs.assetCount
        }

    var assetCount: Int {
        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(in: self, options: fetchOptions)
        return result.count
    }

    static var allAlbums: [PHAssetCollection] {
        let smartAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        var smartAlbums: [PHAssetCollection] = []

        smartAlbumAssetCollections.enumerateObjects { collection, _, _ in
            smartAlbums.append(collection)
        }

        let userAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var userAlbums: [PHAssetCollection] = []

        userAlbumAssetCollections.enumerateObjects { collection, _, _ in
            userAlbums.append(collection)
        }

        return smartAlbums + userAlbums
    }
}
