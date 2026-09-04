//
//  PhotoGridItemView.swift
//  Nextcloud
//
//  Created by Dhanesh on 04/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import NextcloudKit

struct PhotoGridItemView: View {
    @Environment(\.localAccount) var localAccount: String
    
    let album: Album
    let photo: AlbumPhoto      
    let isVideo: Bool
    let metadata: tableMetadata?
    let iconSize: CGFloat
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    
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
                } else if !photo.hasPreview {
                    // Show a generic icon if the API says there is no preview
                    Image(systemName: "doc").foregroundColor(.gray)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .overlay(
            Group {
                if isVideo {
                    Image(systemName: "play.fill")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.white)
                        .padding(8)
                }
            },
            alignment: .bottomLeading
        )
        .cornerRadius(8)
        // Use photo.id to trigger the task
        .task(id: photo.id) {
            await loadThumbnailFromPhoto()
        }
    }
    
    private func loadThumbnailFromPhoto() async {
        // 1. Validate: Only load if it has a preview and a valid ID
        guard photo.hasPreview, !photo.id.isEmpty else {
            return
        }

        // 2. Clear previous state for reused cells
        await MainActor.run {
            self.thumbnail = nil
            self.isLoading = true
        }

        // 3. Setup parameters from Photo object and Metadata fallback
        let fileId = photo.id
        let userId = metadata?.userId ?? ""
        let urlBase = metadata?.urlBase ?? ""
        let etag = metadata?.etag ?? ""

        // 4. Try Disk Cache First
        if let cachedImage = NCUtility().getImage(
            ocId: fileId,
            etag: etag,
            ext: NCGlobal.shared.previewExt512,
            userId: userId,
            urlBase: urlBase
        ) {
            await MainActor.run {
                self.thumbnail = cachedImage
                self.isLoading = false
            }
            return
        }

        // 5. Download Preview
        let results = await NextcloudKit.shared.downloadPreviewAsync(
            fileId: fileId,
            etag: etag,
            account: localAccount
        ) { _ in }

        await MainActor.run {
            if results.error == .success,
               let data = results.responseData?.data,
               let image = UIImage(data: data) {
                self.thumbnail = image
                
                // 6. Save to cache (optional but recommended)
                Task.detached(priority: .background) {
                    await NCUtility().createImageFileFrom(
                        data: data, ocId: fileId, etag: etag, userId: userId, urlBase: urlBase
                    )
                }
            }
            self.isLoading = false
        }
    }
}

