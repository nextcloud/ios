//
//  PhotosGridView.swift
//  Nextcloud
//
//  Created by Dhanesh on 01/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct PhotosGridView: View {
    let localAccount: String // Add this
    let photos: [AlbumPhoto : tableMetadata?]
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
                        openPhotoViewer(photo: photo, metadata: metadata)
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
    
    private func openPhotoViewer(photo: AlbumPhoto, metadata: tableMetadata?) {
        // Build a complete, ordered metadata list matching the grid order
        // 1) Establish a single, consistent order identical to the grid
        let orderedPhotos = photos.keys.sorted { lhs, rhs in
            lhs.fileName.localizedCaseInsensitiveCompare(rhs.fileName) == .orderedAscending
        }

        // 2) Build full metadatas list, creating/saving stubs where needed
        var metadatas: [tableMetadata] = []
        metadatas.reserveCapacity(orderedPhotos.count)

        for p in orderedPhotos {
            // Prefer provided dictionary value; if nil, try DB; otherwise create a stub and save it
            if let existing = photos[p] ?? NCManageDatabase.shared.getMetadataFromOcId(p.id) {
                metadatas.append(existing)
            } else {
                let stub = tableMetadata()
                stub.ocId = p.id
                stub.fileId = p.id
                stub.fileName = p.fileName
                stub.account = self.localAccount
                stub.path = "\(album.href)\(p.fileName)"
                // Save the stub so it is available for the viewer and later lookups
                NCManageDatabase.shared.addMetadata(stub)
                metadatas.append(stub)
            }
        }

        // 3) Compute ocIds and currentIndex
        let ocIds = metadatas.map { $0.ocId }
        // Try to find the current index by ocId; fall back to orderedPhotos position if needed
        var resolvedCurrentIndex: Int? = metadatas.firstIndex(where: { $0.ocId == photo.id })
        if resolvedCurrentIndex == nil {
            // Fallback: try by fileId match
            resolvedCurrentIndex = metadatas.firstIndex(where: { $0.fileId == photo.id })
        }
        if resolvedCurrentIndex == nil {
            // As a last resort, align with the orderedPhotos position
            if let fallbackIdx = orderedPhotos.firstIndex(where: { $0.id == photo.id }) {
                resolvedCurrentIndex = fallbackIdx
            }
        }
        guard let currentIndex = resolvedCurrentIndex else {
            print("[PhotosGridView] Could not resolve currentIndex for photo id: \(photo.id)")
            return
        }

        // 4) Navigation and Viewer Setup
        guard let navController = (UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: { $0.isKeyWindow })?.rootViewController as? NCMainTabBarController)?
            .selectedViewController as? UINavigationController else {
                print("[PhotosGridView] Could not find active UINavigationController to present viewer")
                return
            }

        guard let viewer = UIStoryboard(name: "NCViewerMediaPage", bundle: nil)
            .instantiateInitialViewController() as? NCViewerMediaPage else {
                print("[PhotosGridView] Failed to instantiate NCViewerMediaPage from storyboard")
                return
            }

        viewer.hidesBottomBarWhenPushed = true

        // 5) Populate viewer with the complete, ordered arrays
        viewer.ocIds = ocIds
        viewer.metadatas = metadatas
        viewer.currentIndex = currentIndex
        viewer.albumName = album.name
        viewer.albumServerUrl = album.href
        viewer.albumPhoto = photo

        navController.pushViewController(viewer, animated: true)
    }
}
