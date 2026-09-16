// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct AlbumGridItemView: View {
    let album: Album
    let iconSize: CGFloat // Receive the calculated size
    @Environment(\.localAccount) var localAccount: String
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    private let fixedThumbnailHeight: CGFloat = 160

    private var dynamicHeight: CGFloat {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 260
        } else {
            // iPhone logic
            return fixedThumbnailHeight
        }
    }
    private enum ImageState { case loading, empty, thumbnail(UIImage) }
    @State private var imageState: ImageState = .empty

    var body: some View {
        GeometryReader { geo in
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
                        .frame(
                            width: geo.size.width,
                            height: dynamicHeight,
                            alignment: .center
                        )
                        .padding()
                case .thumbnail(let img):
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill() // Ensures the image fills the area (cropping excess)
                        .frame(width: geo.size.width, height: dynamicHeight) // Matches the grid item size
                        .clipped() // Prevents the image from bleeding outside the 8pt corner radius

                }
            }
            .frame(width: geo.size.width, height: dynamicHeight)
            .clipped()
            .overlay(frame)
            .cornerRadius(8)
        }
        .frame(height: dynamicHeight)
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
            imageState = .thumbnail(image)
            return
        }

        imageState = .loading
        if let photoId = album.lastPhotoId,
           !photoId.isEmpty,
           photoId != "-1",
           let image = await downloadThumbnail(fileId: photoId) {
            guard !Task.isCancelled else { return }
            imageState = .thumbnail(image)
            return
        }
        guard !Task.isCancelled else { return }

        // Fetch album entries only when the server's preferred cover is unavailable.
        let albumName = album.name
        let account = localAccount
        let preferredPhotoId = album.lastPhotoId
        let candidateIds: [String] = await withCheckedContinuation { continuation in
            NextcloudKit.shared.fetchAlbumPhotos(
                for: albumName,
                account: account,
                options: NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)
            ) { result in
                let photos = (try? result.get()) ?? []
                var seen = Set<String>()
                let candidates = photos.filter {
                    $0.hasPreview && !$0.fileId.isEmpty && $0.fileId != preferredPhotoId
                }.sorted {
                    if $0.lastModified != $1.lastModified {
                        return $0.lastModified > $1.lastModified
                    }
                    return $0.fileId < $1.fileId
                }.compactMap { photo in
                    seen.insert(photo.fileId).inserted ? photo.fileId : nil
                }
                continuation.resume(returning: Array(candidates.prefix(5)))
            }
        }
        guard !Task.isCancelled else { return }

        for photoId in candidateIds {
            if let image = await downloadThumbnail(fileId: photoId) {
                guard !Task.isCancelled else { return }
                imageState = .thumbnail(image)
                return
            }
            guard !Task.isCancelled else { return }
        }
        imageState = .empty
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
