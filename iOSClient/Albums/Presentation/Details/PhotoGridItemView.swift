// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct PhotoGridItemView: View {
    @Environment(\.localAccount) var localAccount: String

    let album: Album
    let photo: AlbumPhoto
    let aspectRatio: CGFloat
    let showsMediaTypeIcon: Bool
    private var metadata: tableMetadata { photo.metadata }

    private var mediaTypeIconName: String? {
        if metadata.isVideo {
            return "play.fill"
        } else if metadata.isLivePhoto {
            return "livephoto"
        }
        return nil
    }

    @State private var thumbnail: UIImage?
    @State private var isLoading = false

    init(
        album: Album,
        photo: AlbumPhoto,
        aspectRatio: CGFloat = 1,
        showsMediaTypeIcon: Bool = true
    ) {
        self.album = album
        self.photo = photo
        self.aspectRatio = aspectRatio
        self.showsMediaTypeIcon = showsMediaTypeIcon
    }

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Color.gray.opacity(0.15))
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if !metadata.hasPreview {
                    // Show a generic icon if the API says there is no preview
                    Image(systemName: "doc").foregroundColor(.gray)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .aspectRatio(aspectRatio, contentMode: .fill)
        .clipped()
        .overlay(
            Group {
                if showsMediaTypeIcon, let mediaTypeIconName {
                    Image(systemName: mediaTypeIconName)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.white)
                        .padding(5)
                }
            },
            alignment: .bottomLeading
        )
        // Use photo.id to trigger the task
        .task(id: photo.id) {
            await loadThumbnailFromPhoto()
        }
    }

    private func loadThumbnailFromPhoto() async {
        // Clear the previous image before validating the new photo. Otherwise a
        // reused cover view could keep showing a removed photo with no replacement.
        await MainActor.run {
            self.thumbnail = nil
            self.isLoading = !photo.id.isEmpty
        }

        // 1. Validate the photo ID.
        guard !photo.id.isEmpty else {
            return
        }

        // 2. Setup parameters from Photo object and Metadata fallback.
        let fileId = photo.id
        let ocId = metadata.ocId
        let userId = metadata.userId
        let urlBase = metadata.urlBase
        let etag = metadata.etag
        let previewExt = NCGlobal.shared.previewExt512
        let utility = NCUtility()

        // 3. Look in the preview cache first.
        if let cachedImage = utility.getImage(
            ocId: ocId,
            etag: etag,
            ext: previewExt,
            userId: userId,
            urlBase: urlBase
        ) {
            await MainActor.run {
                self.thumbnail = cachedImage
                self.isLoading = false
            }
            return
        }

        // 4. If the original file is local, generate its preview locally.
        if NCUtilityFileSystem().fileProviderStorageExists(metadata) {
            utility.createImageFileFrom(metadata: metadata)
            if let localImage = utility.getImage(
                ocId: ocId,
                etag: etag,
                ext: previewExt,
                userId: userId,
                urlBase: urlBase
            ) {
                await MainActor.run {
                    self.thumbnail = localImage
                    self.isLoading = false
                }
                return
            }
        }

        // 5. Download the server preview only as the final fallback.
        guard metadata.hasPreview else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }

        let results = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId, etag: etag, account: localAccount) { _ in }

        await MainActor.run {
            if results.error == .success,
               let data = results.responseData?.data,
               let image = UIImage(data: data) {
                self.thumbnail = image

                // 6. Save the downloaded preview to the cache.
                Task.detached(priority: .background) {
                    NCUtility().createImageFileFrom(
                        data: data,
                        ocId: ocId,
                        etag: etag,
                        ext: previewExt,
                        userId: userId,
                        urlBase: urlBase
                    )
                }
            }
            self.isLoading = false
        }
    }
}
