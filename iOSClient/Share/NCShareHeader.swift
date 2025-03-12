//
//  NCShareHeader.swift
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
import TagListView

class NCShareHeader: UIView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var fullWidthImageView: UIImageView!
    @IBOutlet weak var fileNameTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tagListView: TagListView!

    private var heightConstraintWithImage: NSLayoutConstraint?
    private var heightConstraintWithoutImage: NSLayoutConstraint?

    func setupUI(with metadata: tableMetadata) {
        let utilityFileSystem = NCUtilityFileSystem()
        if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024) {
            fullWidthImageView.image = image
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.image = fullWidthImageView.image
            imageView.isHidden = true
        } else {
            if metadata.directory {
                imageView.image = metadata.e2eEncrypted ? NCImageCache.shared.getFolderEncrypted(account: metadata.account) : NCImageCache.shared.getFolder(account: metadata.account)
            } else if !metadata.iconName.isEmpty {
                imageView.image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            } else {
                imageView.image = NCImageCache.shared.getImageFile()
            }

            fileNameTopConstraint.constant -= 45
        }

        fileName.text = metadata.fileNameView
        fileName.textColor = NCBrandColor.shared.textColor
        info.textColor = NCBrandColor.shared.textColor2
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + NCUtility().getRelativeDateTitle(metadata.date as Date)

        tagListView.addTags(Array(metadata.tags))

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if fullWidthImageView.image != nil {
            imageView.isHidden = traitCollection.verticalSizeClass != .compact
        }
    }
}
