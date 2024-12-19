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

    var assetCollections: PHFetchResult<PHAssetCollection>?

    init(controller: NCMainTabBarController?) {
        self.controller = controller
    }

    nonisolated func onViewAppear() {
        Task { @MainActor in
            let allPhotosOptions = PHFetchOptions()
            allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)

            allPhotosCount = allPhotos.count

            assetCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)

            assetCollections?.enumerateObjects { collection, _, _ in
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

extension AlbumModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Change notifications may originate from a background queue.
              // Re-dispatch to the main queue before acting on the change,
              // so you can update the UI.
        Task { @MainActor in
                  // Check each of the three top-level fetches for changes.
                  if let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                      // Update the cached fetch result.
                      allPhotos = changeDetails.fetchResultAfterChanges
                      // Don't update the table row that always reads "All Photos."
                  }

//                  let assetCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

                  // Update the cached fetch results, and reload the table sections to match.
            if let assetCollections, let changeDetails = changeInstance.changeDetails(for: assetCollections) {
                      var results = changeDetails.fetchResultAfterChanges

                smartAlbums.removeAll()

                assetCollections.enumerateObjects { collection, _, _ in
                    self.smartAlbums.append(collection)
                }
//                      tableView.reloadSections(IndexSet(integer: Section.smartAlbums.rawValue), with: .automatic)
                  }
//                  if let changeDetails = changeInstance.changeDetails(for: userCollections) {
//                      userCollections = changeDetails.fetchResultAfterChanges
//                      tableView.reloadSections(IndexSet(integer: Section.userCollections.rawValue), with: .automatic)
//                  }
              }
//        Task { @MainActor in
//            if let changes = changeInstance.changeDetails(for: allPhotos) {
//                allPhotos = changes.fetchResultAfterChanges
//            }
//        }

    }
}
