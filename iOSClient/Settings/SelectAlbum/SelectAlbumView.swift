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
                SelectionButton(tag: SelectAlbumView.cameraRollTag, album: <#T##PHAssetCollection#>  selection: $selectedAlbums) {
                    Image(systemName: "photo")
                    Text(NSLocalizedString("_camera_roll_", comment: ""))
                }
            }

            SmartAlbums(model: model, selectedAlbums: $selectedAlbums)
            UserAlbums(model: model, selectedAlbums: $selectedAlbums)
        }
        .onChange(of: selectedAlbums) { newValue in
            if newValue.count > 1, oldSelectedAlbums.contains(SelectAlbumView.cameraRollTag) {
                selectedAlbums.remove(SelectAlbumView.cameraRollTag)
            } else if newValue.contains(SelectAlbumView.cameraRollTag) {
                selectedAlbums = [SelectAlbumView.cameraRollTag]
            }

            oldSelectedAlbums = newValue
            model.setSavedAlbumIds(selectedAlbums: selectedAlbums)
            model.populateSelectedAlbums()
        }
        .onAppear {
            selectedAlbums = model.getSavedAlbumIds()
        }
        .defaultViewModifier(model)
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
                SelectionButton(tag: album.localIdentifier, album: album, selection: $selectedAlbums)
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
                SelectionButton(tag: album.localIdentifier, album: album, selection: $selectedAlbums)
            }
        }
    }
}

struct SelectionButton: View {
    let tag: String
    let title: String
    let assetCount: String

    @Binding var selection: Set<String>

    init(tag: String, album: PHAssetCollection, selection: Binding<Set<String>>) {
        self.tag = tag
        self.title = album.localizedTitle ?? ""
        self.assetCount = String(album.assetCount)
        self._selection = selection
    }

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
                Text(title)
                Text(assetCount)

            }
        }
        .foregroundColor(.primary)
    }
}
