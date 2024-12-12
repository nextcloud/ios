//
//  AlbumModel.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 12.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Photos

@MainActor class AlbumModel: NSObject, ObservableObject {
    @Published var allPhotos: PHFetchResult<PHAsset>!
    @Published var allPhotosCount = 0
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var selectedSmartAlbums: [PHAssetCollection] = []
//    @Published var albums: Albums
//    @Published var userCollections: PHFetchResult<PHCollection>!
//    let sectionLocalizedTitles = ["", NSLocalizedString("Smart Albums", comment: ""), NSLocalizedString("Albums", comment: "")]

    override init() {
        super.init()

        let allPhotosOptions = PHFetchOptions()
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

//        allPhotos.enumerateObjects { asset, _, _ in
//            self.allPhotos.append(asset)
//        }

        allPhotosCount = allPhotos.count

        let assetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

        assetCollections.enumerateObjects { collection, _, _ in
            self.smartAlbums.append(collection)
        }

        PHPhotoLibrary.shared().register(self)
    }

    func getAlbums(selectedAlbums: Set<String>) {
        selectedSmartAlbums = selectedAlbums.compactMap { selectedAlbum in
            return smartAlbums.first(where: { $0.localIdentifier == selectedAlbum })
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}
