// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
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

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        super.init()

        initAlbums()
        PHPhotoLibrary.shared().register(self)
    }

    func refresh() {
        var newSmartAlbums: [PHAssetCollection] = []
        var newUserAlbums: [PHAssetCollection] = []
//        smartAlbums.removeAll()
//        userAlbums.removeAll()

        Task { @MainActor in
//            smartAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            smartAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                    allPhotosCollection = collection
                } else if collection.assetCount > 0 {
                    newSmartAlbums.append(collection)
                }
            }

            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "estimatedAssetCount > 0") // Only normal albums have an estimated asset count. Smart albums do not and must be calculated manually via .assetCount
//            userAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)

            userAlbumAssetCollections?.enumerateObjects { collection, _, _ in
                newUserAlbums.append(collection)
            }

            smartAlbums = newSmartAlbums
            userAlbums = newUserAlbums

            if let allPhotosCollection, autoUploadAlbumIds.isEmpty {
                setSavedAlbumIds(selectedAlbums: [allPhotosCollection.localIdentifier])
            }
        }
    }

    func initAlbums() {
        var newSmartAlbums: [PHAssetCollection] = []
        var newUserAlbums: [PHAssetCollection] = []
//        smartAlbums.removeAll()
//        userAlbums.removeAll()

        Task { @MainActor in
            smartAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
            smartAlbumAssetCollections?.enumerateObjects { [self] collection, _, _ in
                if collection.assetCollectionSubtype == .smartAlbumUserLibrary {
                    allPhotosCollection = collection
                } else if collection.assetCount > 0 {
                    newSmartAlbums.append(collection)
                }
            }

            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "estimatedAssetCount > 0") // Only normal albums have an estimated asset count. Smart albums do not and must be calculated manually via .assetCount
            userAlbumAssetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options)

            userAlbumAssetCollections?.enumerateObjects { collection, _, _ in
                newUserAlbums.append(collection)
            }

            smartAlbums = newSmartAlbums
            userAlbums = newUserAlbums

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
            //            //
            //            ////             Update the cached fetch results, and reload the table sections to match.
            if let changeDetails = changeInstance.changeDetails(for: smartAlbumAssetCollections) {
                smartAlbumAssetCollections = changeDetails.fetchResultAfterChanges
            }
            //            //
            if let changeDetails = changeInstance.changeDetails(for: userAlbumAssetCollections) {
                userAlbumAssetCollections = changeDetails.fetchResultAfterChanges
                //            //
            }

            refresh()
            //
//            let fetchResultChangeDetails = changeInstance.changeDetails(for: smartAlbumAssetCollections)
//            guard (fetchResultChangeDetails) != nil else {
//                print("No change in fetchResultChangeDetails")
//                return;
//            }
//            print("Contains changes")
//            smartAlbumAssetCollections = (fetchResultChangeDetails?.fetchResultAfterChanges)!
//            let insertedObjects = fetchResultChangeDetails?.insertedObjects
//            let removedObjects = fetchResultChangeDetails?.removedObjects
//            let test = fetchResultChangeDetails?.changedIndexes
//
//            insertedObjects?.forEach({ assetCollection in
//                if assetCollection.assetCount > 0 {
//                    smartAlbums.append(assetCollection)
//                }
//            })
//
//            removedObjects?.forEach({ assetCollection in
//                smartAlbums.removeAll(where: { $0 == assetCollection })
//            })
//
//            test?.forEach({ index in
//                smartAlbums[index] = tes
//            })
//
//            let fetchResultChangeDetails2 = changeInstance.changeDetails(for: userAlbumAssetCollections)
//            guard (fetchResultChangeDetails2) != nil else {
//                print("No change in fetchResultChangeDetails")
//                return;
//            }
//            print("Contains changes")
//            smartAlbumAssetCollections = (fetchResultChangeDetails?.fetchResultAfterChanges)!
//
//            populateSelectedAlbums()
////            let insertedObjects = fetchResultChangeDetails?.insertedObjects
////            let removedObjects = fetchResultChangeDetails?.removedObjects
        }
    }
}
