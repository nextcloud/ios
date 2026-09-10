// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct PhotosGridView: View {
    let localAccount: String
    let photos: [AlbumPhoto: tableMetadata?]
    let onAddPhotosIntent: () -> Void
    let album: Album

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
        let sortedPhotos = photos.keys.sorted { lhs, rhs in
            lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }

        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(sortedPhotos, id: \.self) { photo in
                    let metadata = photos[photo] ?? nil
                    Button {
                        openPhotoViewer(photo: photo)
                    } label: {
                        PhotoGridItemView(
                            album: album,
                            photo: photo,
                            isVideo: (metadata?.isVideo ?? false),
                            metadata: metadata,
                            iconSize: calculatedIconSize
                        )
                    }
                }
            }
        }
    }

    @MainActor
    private func openPhotoViewer(photo: AlbumPhoto) {
        let orderedPhotos = photos.keys.sorted {
            $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
        }
        let resolvedPhotos = orderedPhotos.compactMap { albumPhoto -> (photo: AlbumPhoto, metadata: tableMetadata)? in
            guard let metadata = (photos[albumPhoto] ?? nil)
                ?? NCManageDatabase.shared.getMetadataFromFileId(albumPhoto.id),
                  metadata.account == localAccount else {
                return nil
            }
            return (albumPhoto, metadata.detachedCopy())
        }
        let controller = SceneManager.shared.getController(account: localAccount)
        guard let selected = resolvedPhotos.first(where: { $0.photo.id == photo.id }) else {
            Task { @MainActor in
                await showErrorBanner(
                    windowScene: SceneManager.shared.getWindowScene(controller: controller),
                    text: "_albums_photos_error_msg_"
                )
            }
            return
        }

        let model = NCMediaViewerModel(
            currentMetadata: selected.metadata,
            ocIds: resolvedPhotos.map { $0.metadata.ocId },
            session: NCSession.shared.getSession(account: localAccount),
            loader: NCMediaViewerLoader()
        )
        NCMediaViewerPresenter.shared.show(
            model: model,
            viewerTransitionSource: nil,
            from: controller?.view,
            contextMenuController: nil
        )
    }
}
