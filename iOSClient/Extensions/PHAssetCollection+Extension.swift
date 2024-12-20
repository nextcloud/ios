//
//  PHAssetCollection+Extension.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 12.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Photos

extension PHAssetCollection {
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
