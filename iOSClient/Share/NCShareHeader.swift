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
    @IBOutlet weak var heightWithImage: NSLayoutConstraint!
//    @IBOutlet weak var heightWithoutImage: NSLayoutConstraint!

    private var heightConstraintWithImage: NSLayoutConstraint?
    private var heightConstraintWithoutImage: NSLayoutConstraint?

    override func awakeFromNib() {
        super.awakeFromNib()

//        removeConstraint(heightWithImage)
//        removeConstraint(heightWithoutImage)

//        heightWithImage.isActive = false
//        heightWithoutImage.isActive = false
    }

    func setupUI(with metadata: tableMetadata) {
        let utilityFileSystem = NCUtilityFileSystem()
        if FileManager.default.fileExists(atPath: utilityFileSystem.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            fullWidthImageView.image = NCUtility().getImageMetadata(metadata, for: frame.height)
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.image = fullWidthImageView.image
            imageView.isHidden = true
//            heightWithImage.isActive = true
        } else {
            if metadata.directory {
                imageView.image = metadata.e2eEncrypted ? NCImageCache.images.folderEncrypted : NCImageCache.images.folder
            } else if !metadata.iconName.isEmpty {
                imageView.image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true)
            } else {
                imageView.image = NCImageCache.images.file
            }

            fileNameTopConstraint.constant -= 45
//            heightWithImage.constant = 150
//            heightWithoutImage.isActive = true
        }

        if traitCollection.verticalSizeClass == .compact {
            heightWithImage.constant = 90
        } else {
            heightWithImage.constant = fullWidthImageView.image == nil ? 150 : 230
        }

        fileName.text = metadata.fileNameView
        fileName.textColor = NCBrandColor.shared.textColor
        info.textColor = NCBrandColor.shared.textColor2
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + NCUtility().dateDiff(metadata.date as Date)

        tagListView.addTags(Array(metadata.tags))

//        heightConstraintWithImage = heightAnchor.constraint(equalToConstant: heightWithImage.constant)
//        heightConstraintWithoutImage = heightAnchor.constraint(equalToConstant: heightWithoutImage.constant)

        calculateHeaderHeight()

        setNeedsLayout()
        layoutIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        if traitCollection.verticalSizeClass == .compact { // if height is compact
            heightWithImage.constant = 90
        } else {
            heightWithImage.constant = fullWidthImageView.image == nil ? 150 : 230
        }

        if fullWidthImageView.image != nil {
            imageView.isHidden = traitCollection.verticalSizeClass != .compact
        }
    }

    func viewWillTransitionTo() {
//        heightWithImage.constant -= 20

//        if traitCollection.verticalSizeClass == .compact {
//            heightWithImage.constant = 90
//        } else {
//            heightWithImage.constant = fullWidthImageView.image == nil ? 150 : 230
//        }
//
//        if fullWidthImageView.image != nil {
//            imageView.isHidden = traitCollection.verticalSizeClass == .compact
//        }

    }

    func calculateHeaderHeight() {
//        if fullWidthImageView.image != nil {
////            heightConstraintWithImage?.isActive = true
////            heightConstraintWithoutImage?.isActive = false
////            heightAnchor.constraint(equalToConstant: heightWithImage.constant).isActive = true
//            heightWithoutImage.isActive = false
//
//            heightWithImage.isActive = true
//        } else {
////            heightConstraintWithoutImage?.isActive = true
////            heightConstraintWithImage?.isActive = false
//            heightWithImage.isActive = false
////            heightAnchor.constraint(equalToConstant: heightWithoutImage.constant).isActive = true
//            heightWithoutImage.isActive = true
//        }

//        setNeedsLayout()
//        layoutIfNeeded()
    }
}
