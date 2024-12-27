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
                SelectionButton(tag: SelectAlbumView.cameraRollTag, selection: $selectedAlbums) {
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

            model.getSelectedAlbums(selectedAlbums: selectedAlbums)
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
                SelectionButton(tag: album.localIdentifier, selection: $selectedAlbums) {
                    Text(album.localizedTitle ?? "")
                    Text(String(album.assetCount))
                }
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
                SelectionButton(tag: album.localIdentifier, selection: $selectedAlbums) {
                    Text(album.localizedTitle ?? "")
                    Text(String(album.assetCount))
                }
            }
        }
    }
}

struct SelectionButton<Content: View>: View {
    let tag: String
    @Binding var selection: Set<String>
    @ViewBuilder var content: Content

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
                content
            }
        }
        .foregroundColor(.primary)
    }
}
