// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos

extension BackgroundUploadExtension {
    /// Returns the chunk size when the resource must use the host app's existing upload pipeline.
    /// The host app selects the actual 10 MB or 100 MB chunk size later, using its current network.
    func legacyChunkSize(resource: PHAssetResource) -> Int? {
        let resourceSize = Int64(resource.dataSize ?? 0)
        let directUploadLimit = global.chunkSizeMBEthernetOrWiFi

        return resourceSize > Int64(directUploadLimit) ? directUploadLimit : nil
    }

    /// Returns the legacy chunk size when the combined resources exceed the direct-upload limit.
    /// Live Photo components always follow the same pipeline instead of being split across upload systems.
    func legacyChunkSize(resources: [PHAssetResource]) -> Int? {
        let totalSize = resources.reduce(Int64(0)) { partialResult, resource in
            partialResult + Int64(resource.dataSize ?? 0)
        }
        let directUploadLimit = global.chunkSizeMBEthernetOrWiFi

        return totalSize > Int64(directUploadLimit) ? directUploadLimit : nil
    }
}
