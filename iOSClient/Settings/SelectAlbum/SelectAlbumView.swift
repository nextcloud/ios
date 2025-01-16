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
    @State var selectedAlbums = Set<String>()

    var body: some View {
        List {
            Section {
                SelectionButton(album: model.allPhotosCollection, isSmartAlbum: true, customAssetCount: 0, selection: $selectedAlbums)
            }

            if !model.smartAlbums.isEmpty {
                SmartAlbums(model: model, selectedAlbums: $selectedAlbums)
            }

            if !model.userAlbums.isEmpty {
                UserAlbums(model: model, selectedAlbums: $selectedAlbums)
            }
        }
        .onChange(of: selectedAlbums) { newValue in
            if newValue.count > 1, oldSelectedAlbums.contains(model.allPhotosCollection?.localIdentifier ?? "") {
                selectedAlbums.remove(model.allPhotosCollection?.localIdentifier ?? "")
            } else if newValue.contains(model.allPhotosCollection?.localIdentifier ?? "") {
                selectedAlbums = [model.allPhotosCollection?.localIdentifier ?? ""]
            } else if newValue.isEmpty {
                selectedAlbums = [model.allPhotosCollection?.localIdentifier ?? ""]
            }

            oldSelectedAlbums = newValue
            model.setSavedAlbumIds(selectedAlbums: selectedAlbums)
            model.populateSelectedAlbums()
        }
        .onAppear {
            selectedAlbums = model.getSavedAlbumIds()
        }
    }
}

#Preview {
    SelectAlbumView(model: AlbumModel(controller: nil))
}

struct SmartAlbums: View {
    @ObservedObject var model: AlbumModel
    @Binding var selectedAlbums: Set<String>

    var body: some View {
        Section(NSLocalizedString("_smart_albums_", comment: "")) {
            ForEach(model.smartAlbums, id: \.localIdentifier) { album in
                SelectionButton(album: album, isSmartAlbum: true, selection: $selectedAlbums)
            }
        }
    }
}

struct UserAlbums: View {
    @ObservedObject var model: AlbumModel
    @Binding var selectedAlbums: Set<String>

    var body: some View {
        Section(NSLocalizedString("_albums_", comment: "")) {
            ForEach(model.userAlbums, id: \.localIdentifier) { album in
                SelectionButton(album: album, isSmartAlbum: false, selection: $selectedAlbums)
            }
        }
    }
}

struct SelectionButton: View {
    let album: PHAssetCollection?
    let isSmartAlbum: Bool
    var customAssetCount = 0
    @StateObject var loader: ImageLoader = ImageLoader()
    @Binding var selection: Set<String>

    var body: some View {
        Button(action: {
            withAnimation {
                guard let album else { return }

                if selection.contains(album.localIdentifier) {
                    selection.remove(album.localIdentifier)
                } else {
                    selection.insert(album.localIdentifier)
                }
            }
        }) {
            HStack {
                Image(systemName: selection.contains(album?.localIdentifier ?? "") ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)

                Image(uiImage: loader.image ?? UIImage())
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipped()
                    .cornerRadius(8)

                VStack(alignment: .leading) {
                    Text((album?.assetCollectionSubtype == .smartAlbumUserLibrary) ? NSLocalizedString("_camera_roll_", comment: "") : (album?.localizedTitle ?? ""))
                    Text(String((isSmartAlbum ? album?.assetCount : album?.estimatedAssetCount) ?? 0)) // Only normal albums have an estimated asset count. Smart albums do not and must be calculated manually via .assetCount
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
        .onAppear {
            loader.loadImage(from: album, targetSize: .zero)
        }
    }
}

@MainActor class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func loadImage(from album: PHAssetCollection?, targetSize: CGSize) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let assets: PHFetchResult<PHAsset>

        if let album {
            assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        } else {
            assets = PHAsset.fetchAssets(with: fetchOptions)
        }

        guard let asset = assets.firstObject else { return }

        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.image = image
        }
    }
}
