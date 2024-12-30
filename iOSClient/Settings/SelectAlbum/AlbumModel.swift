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
    @Published var userAlbums: [PHAssetCollection] = []
    @Published var selectedAlbums: [PHAssetCollection] = []
    @Published var controller: NCMainTabBarController?

    var smartAlbumAssetCollections: PHFetchResult<PHAssetCollection>?
    var userAlbumAssetCollections: PHFetchResult<PHAssetCollection>?

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        super.init()

        Task { @MainActor in
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

            allPhotosCount = allPhotos.count

            smartAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

            smartAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                smartAlbums.append(collection)
            }

            userAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)

            userAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                userAlbums.append(collection)
            }
        }
    }

    nonisolated func onViewAppear() {

    }

    func populateSelectedAlbums() {
        let savedAlbums = getSavedAlbumIds()

        selectedAlbums = savedAlbums.compactMap { selectedAlbum in
            return smartAlbums.first(where: { $0.localIdentifier == selectedAlbum })
        }
    }

    func setSavedAlbumIds(selectedAlbums: Set<String>) {
        guard let account = controller?.account else { return }

        NCKeychain().setAutoUploadAlbumIds(account: account, albumIds: Array(selectedAlbums))
    }

    func getSavedAlbumIds() -> Set<String> {
        guard let account = controller?.account else { return [] }

        let albumIds = NCKeychain().getAutoUploadAlbumIds(account: account) ?? []

        return Set(albumIds)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension AlbumModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Change notifications may originate from a background queue.
        // Re-dispatch to the main queue before acting on the change,
        // so you can update the UI.
        Task { @MainActor in
            if let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                allPhotos = changeDetails.fetchResultAfterChanges
            }

//            if let smartAlbumAssetCollections, let changeDetails = changeInstance.changeDetails(for: smartAlbumAssetCollections) {
//                var results = changeDetails.fetchResultAfterChanges
//
//                smartAlbums.removeAll()
//
//                smartAlbumAssetCollections.enumerateObjects { collection, _, _ in
//                    self.smartAlbums.append(collection)
//                }
//            }
//
//            if let userAlbumAssetCollections, let changeDetails = changeInstance.changeDetails(for: userAlbumAssetCollections) {
//                var results = changeDetails.fetchResultAfterChanges
//
//                userAlbums.removeAll()
//
//                userAlbumAssetCollections.enumerateObjects { collection, _, _ in
//                    self.userAlbums.append(collection)
//                }
//            }
        }
    }
}
