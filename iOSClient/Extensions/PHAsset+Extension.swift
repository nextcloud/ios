//
//  PHAsset+Extension.swift
//  Nextcloud
//
//  Created by Milen on 24.05.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit

extension PHAsset {
    var originalFilename: NSString {
        if let resource = PHAssetResource.assetResources(for: self).first {
            return resource.originalFilename as NSString
        } else {
            return self.value(forKey: "filename") as? NSString
            ?? ("IMG_" + CCUtility.getIncrementalNumber() + getExtension()) as NSString 
        }
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
