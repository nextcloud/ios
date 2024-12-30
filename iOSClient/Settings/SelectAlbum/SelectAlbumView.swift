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
    static let cameraRollTag = "-1"

    var body: some View {
        List {
            Section {
                SelectionButton(tag: SelectAlbumView.cameraRollTag, album: nil, loader: ImageLoader(), selection: $selectedAlbums)
            }

            SmartAlbums(model: model, selectedAlbums: $selectedAlbums)
            UserAlbums(model: model, selectedAlbums: $selectedAlbums)
        }
        .onChange(of: selectedAlbums) { newValue in
////            if newValue.count > 1, oldSelectedAlbums.contains(SelectAlbumView.cameraRollTag) {
////                selectedAlbums.remove(SelectAlbumView.cameraRollTag)
////            } else if newValue.contains(SelectAlbumView.cameraRollTag) {
////                selectedAlbums = [SelectAlbumView.cameraRollTag]
//            }
//
////            oldSelectedAlbums = newValue
////            model.setSavedAlbumIds(selectedAlbums: selectedAlbums)
////            model.populateSelectedAlbums()
        }
        .onAppear {
//            selectedAlbums = model.getSavedAlbumIds()
        }
//        .defaultViewModifier(model)
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
                SelectionButton(tag: album.localIdentifier, album: album, loader: ImageLoader(), selection: $selectedAlbums)
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
                SelectionButton(tag: album.localIdentifier, album: album, loader: ImageLoader(), selection: $selectedAlbums)
            }
        }
    }
}

struct SelectionButton: View {
    let tag: String
    let album: PHAssetCollection?
    @ObservedObject var loader: ImageLoader
    @Binding var selection: Set<String>

    var body: some View {
        Button(action: {
            withAnimation {
                if selection.contains(tag) {
                    selection.remove(tag)
                } else {
                    selection.insert(tag)
                }
            }
        }) {
            HStack {
                Image(systemName: selection.contains(tag) ? "checkmark.circle.fill" : "circle")
                Image(uiImage: loader.image ?? .add)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipped()

                Text(album?.localizedTitle ?? NSLocalizedString("_camera_roll_", comment: ""))
                Text(String(album?.assetCount ?? 0))
            }
        }
        .foregroundColor(.primary)
        .onAppear {
            loader.loadImage(from: album, targetSize: .zero)
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func loadImage(from album: PHAssetCollection?, targetSize: CGSize) {
        guard let album else { return }

        let fetchOptions = PHFetchOptions()
//        options.isSynchronous = false
//        options.deliveryMode = .highQualityFormat
        fetchOptions.fetchLimit = 1

//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)

        guard let asset = assets.firstObject else { return }

        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.image = image
        }

//        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { [weak self] image, _ in
//            DispatchQueue.main.async {
//                self?.image = image
//            }
//        }
    }
}
