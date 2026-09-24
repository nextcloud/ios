// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct PhotosGridView: View {
    private unowned let controller: NCMainTabBarController

    let photos: [AlbumPhoto]
    let albumTitle: String
    let onRemovePhoto: (AlbumPhoto) -> Void

    @State private var photoToRemove: AlbumPhoto?
    @State private var openingPhoto: AlbumPhoto?

    init(
        controller: NCMainTabBarController,
        photos: [AlbumPhoto],
        albumTitle: String,
        onRemovePhoto: @escaping (AlbumPhoto) -> Void
    ) {
        self.controller = controller
        self.photos = photos
        self.albumTitle = albumTitle
        self.onRemovePhoto = onRemovePhoto
    }

    private func columns(for width: CGFloat) -> [GridItem] {
        let count = width >= 600 ? 4 : 3
        return Array(repeating: GridItem(.flexible(), spacing: 1), count: count)
    }

    private var sortedPhotos: [AlbumPhoto] {
        photos.sorted { lhs, rhs in
            lhs.metadata.fileNameView.localizedCaseInsensitiveCompare(rhs.metadata.fileNameView) == .orderedAscending
        }
    }

    private var coverPhoto: AlbumPhoto? {
        photos.filter(\.metadata.hasPreview).max {
            if $0.metadata.date != $1.metadata.date {
                return $0.metadata.date.compare($1.metadata.date as Date) == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 16) {
                    if let coverPhoto {
                        Button {
                            openingPhoto = coverPhoto
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                PhotoGridItemView(
                                    photo: coverPhoto,
                                    aspectRatio: 16.0 / 7.0,
                                    showsMediaTypeIcon: false
                                )
                                .id(coverPhoto.id)

                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.7)],
                                    startPoint: .center,
                                    endPoint: .bottom
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(albumTitle)
                                        .font(.title2.bold())

                                    Text(
                                        String.localizedStringWithFormat(
                                            NSLocalizedString("_albums_photos_count_", comment: ""),
                                            photos.count
                                        )
                                    )
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.white)
                                .padding()
                            }
                        }
                        .disabled(openingPhoto != nil)
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 1) {
                        ForEach(sortedPhotos) { photo in
                            Button {
                                openingPhoto = photo
                            } label: {
                                PhotoGridItemView(photo: photo)
                            }
                            .disabled(openingPhoto != nil)
                            .contextMenu {
                                Button(role: .destructive) {
                                    photoToRemove = photo
                                } label: {
                                    Label(
                                        NSLocalizedString("_remove_from_album_", comment: ""),
                                        systemImage: "minus.circle"
                                    )
                                }
                            }
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
        let ocIds = sortedPhotos.map { albumPhoto in
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
