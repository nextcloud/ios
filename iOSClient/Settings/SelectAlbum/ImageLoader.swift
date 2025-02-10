// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Photos

@MainActor class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func loadImage(from album: PHAssetCollection?, targetSize: CGSize) {
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

        PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: nil) { [weak self] image, _ in
            self?.image = image
        }
    }
}
