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
    @State private var oldSelectedAlbums = Set<String>()
    @Binding var selectedAlbums: Set<String>
    private let cameraRollTag = "-1"

    var body: some View {
        Text(NSLocalizedString("_select_autoupload_albums_", comment: ""))

        List(selection: $selectedAlbums) {
            Section {
                HStack {
                    Image(systemName: "photo")
                    Text(NSLocalizedString("_camera_roll_", comment: ""))
                }
                .tag(cameraRollTag)
            }

            SmartAlbums(model: model)

        }
        .environment(\.editMode, .constant(EditMode.active))
        .onChange(of: selectedAlbums) { newValue in
            if newValue.count > 1, oldSelectedAlbums.contains(cameraRollTag) {
                selectedAlbums.remove(cameraRollTag)
            } else if newValue.contains(cameraRollTag) {
                selectedAlbums = [cameraRollTag]
            }

            oldSelectedAlbums = newValue
        }
    }
}

#Preview {
    SelectAlbumView(model: AlbumModel(albums: Albums()), selectedAlbums: .constant(Set()))
}

@MainActor class AlbumModel: NSObject, ObservableObject {
    @Published var allPhotos: PHFetchResult<PHAsset>!
    @Published var allPhotosCount = 0
    @Published var smartAlbums: [PHAssetCollection] = []
    @Published var albums: Albums
//    @Published var userCollections: PHFetchResult<PHCollection>!
//    let sectionLocalizedTitles = ["", NSLocalizedString("Smart Albums", comment: ""), NSLocalizedString("Albums", comment: "")]

    init(albums: Albums) {
        self.albums = albums
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
            albums.smartAlbums.append(collection)
        }

        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
}

extension AlbumModel: PHPhotoLibraryChangeObserver {
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            if let changes = changeInstance.changeDetails(for: allPhotos) {
                allPhotos = changes.fetchResultAfterChanges
            }
        }

    }
}

struct SmartAlbums: View {
    @StateObject var model: AlbumModel

    var body: some View {
        Section(NSLocalizedString("_smart_albums_", comment: "")) {
            ForEach(model.smartAlbums, id: \.localIdentifier) { album in
                HStack {
                    Text(album.localizedTitle ?? "")
                    Text(String(album.assetCount))
                } // Tag each album for selection
                .tag(album.localIdentifier)
            }
        }
    }
}
