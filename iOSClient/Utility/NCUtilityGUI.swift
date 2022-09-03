//
//  NCUtilityGUI.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/08/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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

import UIKit
import NextcloudKit

class NCUtilityGUI: NSObject {
    @objc static let shared: NCUtilityGUI = {
        let instance = NCUtilityGUI()
        return instance
    }()

    func createFilePreviewImage(ocId: String, etag: String, fileNameView: String, classFile: String, iconName: String, status: Int, size: CGFloat = CGFloat(NCGlobal.shared.sizeIcon), createPreview: Bool) -> UIImage? {

        autoreleasepool {
            var imagePreview: UIImage?
            let filePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileNameView)!
            let iconImagePath = CCUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)!

            if FileManager().fileExists(atPath: iconImagePath) {
                imagePreview = UIImage(contentsOfFile: iconImagePath)
            } else if createPreview && status >= NCGlobal.shared.metadataStatusNormal && classFile == NKCommon.typeClassFile.image.rawValue && FileManager().fileExists(atPath: filePath) {
                if let image = UIImage(contentsOfFile: filePath), let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon), isAspectRation: true), let data = image.jpegData(compressionQuality: 0.5) {
                    do {
                        try data.write(to: URL.init(fileURLWithPath: iconImagePath), options: .atomic)
                        imagePreview = image
                    } catch { }
                }
            } else if createPreview && status >= NCGlobal.shared.metadataStatusNormal && classFile == NKCommon.typeClassFile.video.rawValue && FileManager().fileExists(atPath: filePath) {
                if let image = NCUtility.shared.imageFromVideo(url: URL(fileURLWithPath: filePath), at: 0), let image = image.resizeImage(size: CGSize(width: NCGlobal.shared.sizeIcon, height: NCGlobal.shared.sizeIcon), isAspectRation: true), let data = image.jpegData(compressionQuality: 0.5) {
                    do {
                        try data.write(to: URL.init(fileURLWithPath: iconImagePath), options: .atomic)
                        imagePreview = image
                    } catch { }
                }
            } else if !iconName.isEmpty {
                imagePreview = UIImage(named: iconName)
            }

            if let image = imagePreview {
                imagePreview = image.resizeImage(size: CGSize(width: size, height: size), isAspectRation: true)
            }
            return imagePreview
        }
    }
}
