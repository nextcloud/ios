// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct AlbumGridItemView: View {
    let album: Album
    let aspectRatio: CGFloat
    private let onImageLoaded: ((UIImage) -> Void)?
    @Environment(\.localAccount) var localAccount: String
    private enum ImageState { case loading, empty, thumbnail(UIImage) }
    @State private var imageState: ImageState = .empty

    init(
        album: Album,
        aspectRatio: CGFloat = 1,
        onImageLoaded: ((UIImage) -> Void)? = nil
    ) {
        self.album = album
        self.aspectRatio = aspectRatio
        self.onImageLoaded = onImageLoaded
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = width / aspectRatio

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
        .aspectRatio(aspectRatio, contentMode: .fit)
        .task(id: coverCacheId) {
            await loadThumbnail()
        }
    }

    // Keep the successful cover across view recreation and app launches. Changes to
    // the album's cover or item count select a fresh cache entry.
    private var coverCacheId: String {
        let components = [localAccount, album.id, album.lastPhotoId ?? "", album.itemCount.map { String($0) } ?? "unknown"]
        let key = components.map { "\($0.utf8.count):\($0)" }.joined()
        return "album-cover-" + key.md5()
    }

    private var cachedThumbnail: UIImage? {
        guard album.itemCount != 0 else { return nil }
        let session = NCSession.shared.getSession(account: localAccount)
        return NCUtility().getImage(
            ocId: coverCacheId,
            etag: "",
            ext: NCGlobal.shared.previewExt512,
            userId: session.userId,
            urlBase: session.urlBase
        )
    }

    @MainActor
    private func loadThumbnail() async {
        guard !Task.isCancelled else { return }
        guard album.itemCount != 0 else {
            imageState = .empty
            return
        }

        if let image = cachedThumbnail {
            showThumbnail(image)
            return
        }

        imageState = .loading
        if let photoId = album.lastPhotoId,
           !photoId.isEmpty,
           photoId != "-1",
           let image = await downloadThumbnail(fileId: photoId) {
            guard !Task.isCancelled else { return }
            showThumbnail(image)
            return
        }
        guard !Task.isCancelled else { return }

        let preferredPhotoId = album.lastPhotoId
        let photos: [AlbumPhoto]
        if let cached = NCManageDatabase.shared.getAlbumPhotos(album: album) {
            photos = cached.map { AlbumPhoto(metadata: $0) }
        } else {
            photos = (try? await AlbumsManager.shared.refreshAlbumPhotos(album)) ?? []
        }
        let candidateIds = photos.filter {
            $0.metadata.hasPreview && $0.id != preferredPhotoId
        }.sorted {
            if $0.metadata.date != $1.metadata.date {
                return $0.metadata.date.compare($1.metadata.date as Date) == .orderedDescending
            }
            return $0.id < $1.id
        }.prefix(5).map(\.id)
        guard !Task.isCancelled else { return }

        for photoId in candidateIds {
            if let image = await downloadThumbnail(fileId: photoId) {
                guard !Task.isCancelled else { return }
                showThumbnail(image)
                return
            }
            guard !Task.isCancelled else { return }
        }
        imageState = .empty
    }

    @MainActor
    private func showThumbnail(_ image: UIImage) {
        imageState = .thumbnail(image)
        onImageLoaded?(image)
    }

    @MainActor
    private func downloadThumbnail(fileId photoId: String) async -> UIImage? {
        guard !Task.isCancelled else { return nil }
        let resultsPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: photoId, etag: "", account: localAccount) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: localAccount,
                    path: photoId,
                    name: "DownloadPreview")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        // A cancelled request must not overwrite a newer album cover.
        guard !Task.isCancelled else { return nil }
        guard resultsPreview.error == .success,
              let data = resultsPreview.responseData?.data else {
            return nil
        }

        let session = NCSession.shared.getSession(account: localAccount)
        return NCUtility().createImageFileFrom(
            data: data,
            ocId: coverCacheId,
            etag: "",
            ext: NCGlobal.shared.previewExt512,
            userId: session.userId,
            urlBase: session.urlBase
        )
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
