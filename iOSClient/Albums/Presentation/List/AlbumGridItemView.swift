// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct AlbumGridItemView: View {
    let album: Album
    @Environment(\.localAccount) var localAccount: String
    private enum ImageState { case loading, empty, thumbnail(UIImage) }
    @State private var imageState: ImageState = .empty

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width

            ZStack {
                switch imageState {
                case .loading:
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                        )
                case .empty:
                    Image(systemName: "photo.on.rectangle.angled.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            Color(NCBrandColor.shared.getElement(account: localAccount))
                        )
                        .padding()
                case .thumbnail(let img):
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()

                }
            }
            .frame(width: width, height: height)
            .clipped()
            .overlay(frame)
            .cornerRadius(8)
        }
        .aspectRatio(1, contentMode: .fit)
        .task(id: coverRequestId) {
            await loadThumbnail()
        }
    }

    private var coverRequestId: String {
        let components = [localAccount, album.id, album.lastPhotoId ?? "", album.itemCount.map { String($0) } ?? "unknown"]
        let key = components.map { "\($0.utf8.count):\($0)" }.joined()
        return key.md5()
    }

    @MainActor
    private func loadThumbnail() async {
        guard !Task.isCancelled else { return }
        guard album.itemCount != 0 else {
            imageState = .empty
            return
        }

        imageState = .loading
        defer {
            if case .loading = imageState {
                imageState = .empty
            }
        }

        guard let coverPhoto = await coverPhoto(),
              !Task.isCancelled,
              let image = await loadImage(for: coverPhoto),
              !Task.isCancelled else {
            return
        }
        imageState = .thumbnail(image)
    }

    @MainActor
    private func coverPhoto() async -> AlbumPhoto? {
        let cached = NCManageDatabase.shared.getAlbumPhotos(album: album)
        let cachedPhotos = cached?.map { AlbumPhoto(metadata: $0) }
        let cacheIsCurrent: Bool
        if let lastPhotoId = album.lastPhotoId, !lastPhotoId.isEmpty, lastPhotoId != "-1" {
            cacheIsCurrent = cached?.contains(where: { $0.fileId == lastPhotoId }) == true
        } else {
            cacheIsCurrent = true
        }
        let photos: [AlbumPhoto]
        if let cachedPhotos, cacheIsCurrent {
            photos = cachedPhotos
        } else {
            photos = (try? await AlbumsManager.shared.refreshAlbumPhotos(album)) ?? cachedPhotos ?? []
        }

        return photos.filter(\.metadata.hasPreview).max {
            if $0.metadata.date != $1.metadata.date {
                return $0.metadata.date.compare($1.metadata.date as Date) == .orderedAscending
            }
            return $0.id < $1.id
        }
    }

    @MainActor
    private func loadImage(for photo: AlbumPhoto) async -> UIImage? {
        guard !Task.isCancelled else { return nil }

        let metadata = photo.metadata
        let utility = NCUtility()
        let previewExt = NCGlobal.shared.previewExt512

        if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: previewExt, userId: metadata.userId, urlBase: metadata.urlBase) {
            return image
        }

        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            utility.createImageFileFrom(metadata: metadata)
            if let image = utility.getImage(ocId: metadata.ocId, etag: metadata.etag, ext: previewExt, userId: metadata.userId, urlBase: metadata.urlBase) {
                return image
            }
        }

        guard metadata.hasPreview else { return nil }
        return await downloadThumbnail(metadata: metadata)
    }

    @MainActor
    private func downloadThumbnail(metadata: tableMetadata) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let fileId = metadata.fileId
        let resultsPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId, etag: metadata.etag, account: localAccount) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: localAccount, path: fileId, name: "DownloadPreview")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        // A cancelled request must not overwrite a newer album cover.
        guard !Task.isCancelled else { return nil }
        guard resultsPreview.error == .success,
              let data = resultsPreview.responseData?.data else {
            return nil
        }

        return NCUtility().createImageFileFrom(data: data, metadata: metadata, ext: NCGlobal.shared.previewExt512)
    }

    private var frame: some View {
        RoundedRectangle(
            cornerRadius: 8
        )
        .stroke(
            Color.gray.opacity(1),
            lineWidth: 1 / UIScreen.main.scale
        )
    }
}
