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
    @State private var imageState: ImageState = .loading

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
        .task(id: album.lastPhotoId) {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        if album.lastPhotoId == "-1" || (album.itemCount ?? 0) == 0 {
            imageState = .empty
            return
        }
        guard let photoId = album.lastPhotoId else {
            imageState = .empty
            return
        }

        Task {

            let resultsPreview = await NextcloudKit.shared.downloadPreviewAsync(fileId: photoId, etag: "", account: localAccount) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: localAccount,
                                                                                                path: photoId,
                                                                                                name: "DownloadPreview")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }
            if resultsPreview.error == .success, let data = resultsPreview.responseData?.data {
                let session = NCSession.shared.getSession(account: localAccount)
                if let image = NCUtility().createImageFileFrom(
                    data: data,
                    ocId: photoId,
                    etag: "",
                    ext: NCGlobal.shared.previewExt512,
                    userId: session.userId,
                    urlBase: session.urlBase
                ) {
                    Task { @MainActor in
                        await MainActor.run { imageState = .thumbnail(image) }
                    }
                } else {
                    await MainActor.run { imageState = .empty }
                }
            }
        }
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
