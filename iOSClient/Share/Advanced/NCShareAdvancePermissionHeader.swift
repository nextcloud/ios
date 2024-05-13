//
//  NCShareAdvancePermissionHeader.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
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

class NCShareAdvancePermissionHeader: UIView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var fullWidthImageView: UIImageView!

    func setupUI(with metadata: tableMetadata) {
        let utilityFileSystem = NCUtilityFileSystem()
        if FileManager.default.fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            fullWidthImageView.image = NCUtility().getImageMetadata(metadata, for: frame.height)
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.isHidden = true
        } else {
            if metadata.directory {
                imageView.image = metadata.e2eEncrypted ? NCImageCache.images.folderEncrypted : NCImageCache.images.folder
            } else if !metadata.iconName.isEmpty {
                imageView.image = NCUtility().loadImage(named: metadata.iconName)
            } else {
                imageView.image = NCImageCache.images.file
            }
        }
        fileName.text = metadata.fileNameView
        fileName.textColor = .label
        info.textColor = .secondaryLabel
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + NCUtility().dateDiff(metadata.date as Date)
    }
}
