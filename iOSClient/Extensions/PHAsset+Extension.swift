//
//  PHAsset+Extension.swift
//  Nextcloud
//
//  Created by Milen on 24.05.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import UIKit
import Photos

extension PHAsset {
    var originalFilename: NSString {
        if let resource = PHAssetResource.assetResources(for: self).first {
            return resource.originalFilename as NSString
        } else {
            return self.value(forKey: "filename") as? NSString
            ?? ("IMG_" + NCKeychain().incrementalNumber + getExtension()) as NSString
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
