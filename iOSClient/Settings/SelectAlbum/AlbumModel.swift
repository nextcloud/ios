// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Photos

@MainActor class AlbumModel: NSObject, ObservableObject {
    @Published var allPhotosCollection: PHAssetCollection?
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var userAlbums: [PHAssetCollection] = []
    @Published var selectedAlbums: [PHAssetCollection] = []
    @Published var controller: NCMainTabBarController?

    var smartAlbumAssetCollections: PHFetchResult<PHAssetCollection>!
    var userAlbumAssetCollections: PHFetchResult<PHAssetCollection>!

    var autoUploadAlbumIds: Set<String> {
        getSavedAlbumIds()
    }
    
    init(controller: NCMainTabBarController?) {
        self.controller = controller
        super.init()

        initAlbums()
    }

    func initAlbums() {
        smartAlbums.removeAll()
        userAlbums.removeAll()
        
        Task { @MainActor in
            smartAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            smartAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                    allPhotosCollection = collection
                } else if collection.assetCount > 0 {
                    smartAlbums.append(collection)
                }
            }

            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "estimatedAssetCount > 0") // Only normal albums have an estimated asset count. Smart albums do not and must be calculated manually via .assetCount
            userAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)

            userAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                userAlbums.append(collection)
            }

            if let allPhotosCollection, autoUploadAlbumIds.isEmpty {
                setSavedAlbumIds(selectedAlbums: [allPhotosCollection.localIdentifier])
            }
        }
    }

    func populateSelectedAlbums() {
        let savedAlbums = getSavedAlbumIds()

        selectedAlbums = savedAlbums.compactMap { selectedAlbum in
            return smartAlbums.first(where: { $0.localIdentifier == selectedAlbum }) ?? userAlbums.first(where: { $0.localIdentifier == selectedAlbum })
        }
    }

    func setSavedAlbumIds(selectedAlbums: Set<String>) {
        guard let account = controller?.account else { return }

        NCKeychain().setAutoUploadAlbumIds(account: account, albumIds: Array(selectedAlbums))
    }

    func getSavedAlbumIds() -> Set<String> {
        guard let account = controller?.account else { return [] }

        let albumIds = NCKeychain().getAutoUploadAlbumIds(account: account)

        return Set(albumIds)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension AlbumModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            // Update the cached fetch results, and reload the table sections to match.
            if let changeDetails = changeInstance.changeDetails(for: smartAlbumAssetCollections) {
                smartAlbumAssetCollections = changeDetails.fetchResultAfterChanges
                smartAlbums.removeAll()
                smartAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                    if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                        allPhotosCollection = collection
                    } else if collection.assetCount > 0 {
                        smartAlbums.append(collection)
                    }
                }
            }

            if let changeDetails = changeInstance.changeDetails(for: userAlbumAssetCollections) {
                userAlbumAssetCollections = changeDetails.fetchResultAfterChanges
                userAlbums.removeAll()
                userAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                    userAlbums.append(collection)
                }
            }
        }
    }
}
