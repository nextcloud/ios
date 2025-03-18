// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Photos

struct SelectAlbumView: View {
    @ObservedObject var model: AlbumModel
    @State private var oldSelectedAlbums = Set<String>()
    @State var selectedAlbums = Set<String>()

    var body: some View {
        List {
            Section {
                SelectionButton(model: model, album: model.allPhotosCollection, isSmartAlbum: true, selection: $selectedAlbums)
            }

            if !model.smartAlbums.isEmpty {
                AlbumView(model: model, selectedAlbums: $selectedAlbums, albums: $model.smartAlbums, sectionTitle: "_smart_albums_")
            }

            if !model.userAlbums.isEmpty {
                AlbumView(model: model, selectedAlbums: $selectedAlbums, albums: $model.userAlbums, sectionTitle: "_albums_")
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
        .navigationBarTitle(NSLocalizedString("_upload_from_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)

    }
}

#Preview {
    SelectAlbumView(model: AlbumModel(controller: nil))
}

struct AlbumView: View {
    @ObservedObject var model: AlbumModel
    @Binding var selectedAlbums: Set<String>
    @Binding var albums: [PHAssetCollection]
    let sectionTitle: String

    var body: some View {
        Section(NSLocalizedString(sectionTitle, comment: "")) {
            ForEach(albums, id: \.localIdentifier) { album in
                SelectionButton(model: model, album: album, isSmartAlbum: true, assetCount: album.assetCount, selection: $selectedAlbums)
            }
        }
    }
}

struct SelectionButton: View {
    let model: AlbumModel
    let album: PHAssetCollection?
    let isSmartAlbum: Bool
    var assetCount = 0
    @StateObject var loader = PHAssetCollectionThumbnailLoader()
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
                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                    .imageScale(.large)

                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 70, height: 70)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .imageScale(.large)
                        .frame(width: 70, height: 70)
                        .foregroundStyle(.tertiary)
                        .background(.quaternary.opacity(0.5))
                        .clipped()
                        .cornerRadius(8)
                }

                VStack(alignment: .leading) {
                    Text((album?.assetCollectionSubtype == .smartAlbumUserLibrary) ? NSLocalizedString("_camera_roll_", comment: "") : (album?.localizedTitle ?? ""))
                    Text(String(assetCount)) // Only normal albums have an estimated asset count. Smart albums do not and must be calculated manually via .assetCount
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundColor(.primary)
        .onAppear {
            loader.loadThumbnail(for: album)
        }
    }
}
