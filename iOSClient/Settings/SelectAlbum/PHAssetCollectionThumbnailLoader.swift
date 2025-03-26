// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Photos

@MainActor class PHAssetCollectionThumbnailLoader: ObservableObject {
    @Published var image: UIImage?

    func loadThumbnail(for album: PHAssetCollection?) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let assets: PHFetchResult<PHAsset>

        if let album {
            assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
        } else {
            assets = PHAsset.fetchAssets(with: fetchOptions)
        }

        guard let asset = assets.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true

        PHImageManager.default().requestImage(for: asset, targetSize: .zero, contentMode: .aspectFill, options: options) { [weak self] image, _ in
            self?.image = image
        }
    }
}
