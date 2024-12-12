//
//  PHAssetCollection+Extension.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 12.12.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Photos

extension PHAssetCollection {
    var assetCount: Int {
        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(in: self, options: fetchOptions)
        return result.count
    }
}
