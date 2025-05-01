// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit
import Photos

extension PHAsset {
    // Must be in primary Task
    //
    var originalFilename: String {
        if let resource = PHAssetResource.assetResources(for: self).first {
            return resource.originalFilename
        }

        if let filename = self.value(forKey: "filename") as? String {
            return filename
        }

        return "IMG_" + NCKeychain().incrementalNumber + getExtension()
    }

    private func getExtension() -> String {
        switch mediaType {
        case .video:
            return ".mp4"
        case .image:
            return ".jpg"
        case .audio:
            return ".mp3"
        default:
            return ".unknownType"
        }
    }
}
