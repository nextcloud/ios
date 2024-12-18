//
//  AlbumModel.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 12.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Photos

@MainActor class AlbumModel: NSObject, ObservableObject, ViewOnAppearHandling {
    @Published var allPhotos: PHFetchResult<PHAsset>!
    @Published var allPhotosCount = 0
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var selectedSmartAlbums: [PHAssetCollection] = []
    @Published var controller: NCMainTabBarController?

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        super.init()
        
        PHPhotoLibrary.shared().register(self)
    }

    nonisolated func onViewAppear() {
        Task { @MainActor in
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

            allPhotosCount = allPhotos.count

            let assetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

            assetCollections.enumerateObjects { collection, _, _ in
                self.smartAlbums.append(collection)
            }
        }
    }

    func getSelectedAlbums(selectedAlbums: Set<String>) {
        guard let account = controller?.account else { return }

        NCKeychain().setAutoUploadAlbumIds(account: account, albumIds: Array(selectedAlbums))
        selectedSmartAlbums = selectedAlbums.compactMap { selectedAlbum in
            return smartAlbums.first(where: { $0.localIdentifier == selectedAlbum })
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}
