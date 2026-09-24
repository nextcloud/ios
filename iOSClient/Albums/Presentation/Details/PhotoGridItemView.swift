// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

struct PhotoGridItemView: View {
    @Environment(\.localAccount) var localAccount: String

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
        photo: AlbumPhoto,
        aspectRatio: CGFloat = 1,
        showsMediaTypeIcon: Bool = true
    ) {
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

    @MainActor
    private func loadThumbnailFromPhoto() async {
        // Clear the previous image before validating the new photo. Otherwise a
        // reused cover view could keep showing a removed photo with no replacement.
        thumbnail = nil
        isLoading = !photo.id.isEmpty
        defer { isLoading = false }

        guard !photo.id.isEmpty else {
            return
        }

        let image = await Self.loadPreview(for: photo, account: localAccount)
        guard !Task.isCancelled else { return }
        thumbnail = image
    }

    @MainActor
    static func loadPreview(for photo: AlbumPhoto, account: String) async -> UIImage? {
        guard !Task.isCancelled, !photo.id.isEmpty else { return nil }

        let metadata = photo.metadata
        let fileId = photo.id
        let ocId = metadata.ocId
        let userId = metadata.userId
        let urlBase = metadata.urlBase
        let etag = metadata.etag
        let previewExt = NCGlobal.shared.previewExt512
        let utility = NCUtility()

        if let cachedImage = utility.getImage(ocId: ocId, etag: etag, ext: previewExt, userId: userId, urlBase: urlBase) {
            return cachedImage
        }

        guard metadata.hasPreview else { return nil }

        let results = await NextcloudKit.shared.downloadPreviewAsync(fileId: fileId, etag: etag, account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                    account: account,
                    path: fileId,
                    name: "DownloadPreview"
                )
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        }
        guard !Task.isCancelled else { return nil }

        guard results.error == .success,
              let data = results.responseData?.data,
              let image = UIImage(data: data) else {
            return nil
        }

        Task.detached(priority: .background) {
            NCUtility().createImageFileFrom(data: data, ocId: ocId, etag: etag, ext: previewExt, userId: userId, urlBase: urlBase)
        }

        return image
    }
}
