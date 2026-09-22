// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct PhotosGridView: View {
    private unowned let controller: NCMainTabBarController

    let photos: [AlbumPhoto]
    let onAddPhotosIntent: () -> Void
    let album: Album
    let onRemovePhoto: (AlbumPhoto) -> Void

    @State private var photoToRemove: AlbumPhoto?
    @State private var openingPhoto: AlbumPhoto?

    init(controller: NCMainTabBarController, photos: [AlbumPhoto], onAddPhotosIntent: @escaping () -> Void, album: Album, onRemovePhoto: @escaping (AlbumPhoto) -> Void) {
        self.controller = controller
        self.photos = photos
        self.onAddPhotosIntent = onAddPhotosIntent
        self.album = album
        self.onRemovePhoto = onRemovePhoto
    }

    private var columns: [GridItem] {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return Array(repeating: GridItem(.flexible(), spacing: 1), count: 3)
        } else {
            return [GridItem(.adaptive(minimum: 100, maximum: 300), spacing: 1)]
        }
    }

    private let calculatedIconSize: CGFloat = 30

    var body: some View {
        // Sort by filename or date to ensure stability
        let sortedPhotos = photos.sorted { lhs, rhs in
            lhs.metadata.fileNameView.localizedCaseInsensitiveCompare(rhs.metadata.fileNameView) == .orderedAscending
        }

        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(sortedPhotos) { photo in
                    Button {
                        openingPhoto = photo
                    } label: {
                        PhotoGridItemView(album: album, photo: photo, iconSize: calculatedIconSize)
                    }
                    .disabled(openingPhoto != nil)
                    .contextMenu {
                        Button(role: .destructive) {
                            photoToRemove = photo
                        } label: {
                            Label(NSLocalizedString("_remove_from_album_", comment: ""), systemImage: "minus.circle")
                        }
                    }
                }
            }
        }
        .overlay {
            if openingPhoto != nil {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .task(id: openingPhoto?.id) {
            guard let photo = openingPhoto else { return }
            await openPhotoViewer(photo: photo)
        }
        .alert(
            NSLocalizedString("_remove_from_album_", comment: ""),
            isPresented: Binding(
                get: { photoToRemove != nil },
                set: { if !$0 { photoToRemove = nil } }
            ),
            presenting: photoToRemove
        ) { photo in
            Button(NSLocalizedString("_remove_from_album_", comment: ""), role: .destructive) {
                onRemovePhoto(photo)
            }
            Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) {}
        } message: { _ in
            Text(NSLocalizedString("_want_remove_from_album_", comment: ""))
        }
    }

    @MainActor
    private func openPhotoViewer(photo: AlbumPhoto) async {
        defer { openingPhoto = nil }
        let account = controller.account
        let database = NCManageDatabase.shared
        var selected = await database.getMetadataAsync(
            predicate: NSPredicate(format: "account == %@ AND fileId == %@", account, photo.id)
        )
        guard !Task.isCancelled else { return }

        if selected == nil {
            let result = await NextcloudKit.shared.getFileFromFileIdAsync(fileId: photo.id, account: account)
            guard !Task.isCancelled else { return }
            if result.error == .success, let file = result.file {
                let metadata = await NCManageDatabaseCreateMetadata().convertFileToMetadataAsync(file)
                if metadata.account == account {
                    await database.addMetadataAsync(metadata)
                    selected = metadata
                }
            }
        }

        guard !Task.isCancelled else { return }
        guard let selected,
              let instanceId = NCUtility().splitOcId(selected.ocId).instanceId else {
            await showErrorBanner(
                windowScene: SceneManager.shared.getWindowScene(controller: controller),
                text: "_albums_photos_error_msg_"
            )
            return
        }

        // Album entries provide numeric file IDs. The selected file supplies the server's
        // instance suffix so the viewer can resolve every other file lazily by its ocId.
        let utility = NCUtility()
        let ocIds = photos.sorted {
            $0.metadata.fileNameView.localizedCaseInsensitiveCompare($1.metadata.fileNameView) == .orderedAscending
        }.map { albumPhoto in
            albumPhoto.id == photo.id
                ? selected.ocId
                : utility.paddedFileId(albumPhoto.id) + instanceId
        }
        let model = NCMediaViewerModel(
            currentMetadata: selected,
            ocIds: ocIds,
            session: NCSession.shared.getSession(account: account),
            loader: NCMediaViewerLoader()
        )
        NCMediaViewerPresenter.shared.show(
            model: model,
            viewerTransitionSource: nil,
            from: controller.view,
            contextMenuController: nil
        )
    }
}
