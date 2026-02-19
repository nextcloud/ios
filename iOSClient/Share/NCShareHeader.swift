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
import NextcloudKit

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
        if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase) {
            fullWidthImageView.image = image
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.image = fullWidthImageView.image
            imageView.isHidden = true
        } else {
            if metadata.directory {
                imageView.image = metadata.e2eEncrypted ? NCImageCache.shared.getFolderEncrypted() : NCImageCache.shared.getFolder()
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

class NCShareAdvancePermissionHeader: UITableViewHeaderFooterView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var favorite: UIButton!
    @IBOutlet weak var fullWidthImageView: UIImageView!

    static let reuseIdentifier = "NCShareAdvancePermissionHeader"

    var ocId = ""
    let utility = NCUtility()
    let utilityFileSystem = NCUtilityFileSystem()
    var shares: (firstShareLink: tableShare?, share: [tableShare]?) = (nil, nil)

    func setupUI(with metadata: tableMetadata) {
        fileName.textColor = NCBrandColor.shared.label
        info.textColor = NCBrandColor.shared.textInfo

        let isShare = metadata.permissions.contains(NCPermissions().permissionShared)

        if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase) {
            fullWidthImageView.image = image
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.isHidden = true
        } else {
            imageView.isHidden = false
            if metadata.e2eEncrypted {
                imageView.image = NCImageCache.shared.getFolderEncrypted()
            } else if isShare || !metadata.shareType.isEmpty {
                imageView.image = NCImageCache.shared.getFolderPublic()
            } else if !metadata.shareType.isEmpty {
                imageView.image = metadata.shareType.contains(3)
                    ? NCImageCache.shared.getFolderPublic()
                    : NCImageCache.shared.getFolderSharedWithMe()
            } else if metadata.permissions.contains("S"), (metadata.permissions.range(of: "S") != nil) {
                imageView.image = NCImageCache.shared.getImageSharedWithMe()
            } else if metadata.directory {
                imageView.image = NCImageCache.shared.getFolder()
            } else if !metadata.iconName.isEmpty {
                imageView.image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
            } else {
                imageView.image = NCImageCache.shared.getImageFile()
            }
        }

        fileName.text = metadata.fileNameView
        fileName.textColor = NCBrandColor.shared.fileFolderName

        updateFavoriteIcon(isFavorite: metadata.favorite)
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + utility.getRelativeDateTitle(metadata.date as Date)
    }
    
    func setupUI(with metadata: tableMetadata, linkCount: Int, emailCount: Int) {
        fileName.textColor = NCBrandColor.shared.label
        info.textColor = NCBrandColor.shared.textInfo
        
        let isShare = metadata.permissions.contains(NCPermissions().permissionShared)
        let isMounted = metadata.permissions.contains(NCPermissions().permissionMounted)
        let hasEmailAndLinkShares = (linkCount > 0 && emailCount > 0)
        
        if let image = NCUtility().getImage(ocId: metadata.ocId, etag: metadata.etag, ext: NCGlobal.shared.previewExt1024, userId: metadata.userId, urlBase: metadata.urlBase) {
            fullWidthImageView.image = image
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.isHidden = true
        } else {
            imageView.isHidden = false
            if metadata.directory {
                
                if metadata.e2eEncrypted {
                    imageView.image = NCImageCache.shared.getFolderEncrypted()
                } else if metadata.permissions.contains("S"), (metadata.permissions.range(of: "S") != nil) {
                    imageView.image = NCImageCache.shared.getFolderSharedWithMe()
                } else if (!metadata.shareType.isEmpty || !(shares.share?.isEmpty ?? true) || (shares.firstShareLink != nil)) || isShare || hasEmailAndLinkShares {
                    imageView.image = NCImageCache.shared.getFolderPublic()
                } else if metadata.mountType == "group" {
                    imageView.image = NCImageCache.shared.getFolderGroup()
                } else if isMounted {
                    imageView.image = NCImageCache.shared.getFolderExternal()
                } else {
                    imageView.image = NCImageCache.shared.getFolder()
                }
            } else {
                if metadata.iconName.isEmpty {
                    imageView.image = NCImageCache.shared.getImageFile()
                } else {
                    imageView.image = NCUtility().loadImage(named: metadata.iconName, useTypeIconFile: true, account: metadata.account)
                }
            }
        }

        fileName.text = metadata.fileNameView
        fileName.textColor = NCBrandColor.shared.fileFolderName

        updateFavoriteIcon(isFavorite: metadata.favorite)
        info.text = utilityFileSystem.transformedSize(metadata.size) + ", " + utility.getRelativeDateTitle(metadata.date as Date)
    }
    
    private func updateFavoriteIcon(isFavorite: Bool) {
        favorite.setImage(NCUtility().loadImage(named: !isFavorite ? "star" : "star.fill", colors: [NCBrandColor.shared.yellowFavorite], size: 24), for: .normal)
    }
    
    @IBAction func touchUpInsideFavorite(_ sender: UIButton) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }
        NCNetworking.shared.setStatusWaitFavorite(metadata) { error in
            if error == .success {
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
                self.updateFavoriteIcon(isFavorite: metadata.favorite)
            } else {
                NCContentPresenter().showError(error: error)
            }
        }
    }
}
