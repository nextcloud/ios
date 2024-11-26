//
//  SelectAlbumView.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 20.11.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Photos

struct SelectAlbumView: View {
    @ObservedObject var model: AlbumModel

    var body: some View {
        Text(NSLocalizedString("_select_autoupload_albums_", comment: ""))
        List {
            Section {
                HStack {
                    Image(systemName: "photo")
                    Text(NSLocalizedString("_camera_roll_", comment: ""))
                }
            }

            Section(NSLocalizedString("_smart_albums_", comment: "")) {
                ForEach(model.smartAlbums, id: \.self) { album in
                    Text(album.localizedTitle ?? "")
                }
            }

        }
    }
}

#Preview {
    SelectAlbumView(model: AlbumModel())
}

class AlbumModel: NSObject, ObservableObject {
    @Published var allPhotos: PHFetchResult<PHAsset>!
    @Published var allPhotosCount = 0
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var userCollections: PHFetchResult<PHCollection>!
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

        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)

        smartAlbums.enumerateObjects { collection, _, _ in
            self.smartAlbums.append(collection)
        }

        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension AlbumModel: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        if let changes = changeInstance.changeDetails(for: allPhotos) {
            allPhotos = changes.fetchResultAfterChanges
        }
    }
}
