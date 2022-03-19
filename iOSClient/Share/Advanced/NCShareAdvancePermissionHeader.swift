//
//  NCShareAdvancePermissionHeader.swift
//  Nextcloud
//
//  Created by T-systems on 10/08/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
//

import UIKit

class NCShareAdvancePermissionHeader: UIView {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var favorite: UIButton!
    @IBOutlet weak var fullWidthImageView: UIImageView!

    func setupUI(with metadata: tableMetadata) {
        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            fullWidthImageView.image = NCUtility.shared.getImageMetadata(metadata, for: frame.height)
            fullWidthImageView.contentMode = .scaleAspectFill
            imageView.isHidden = true
        } else {
            if metadata.directory {
                imageView.image = UIImage(named: "folder")
            } else if !metadata.iconName.isEmpty {
                imageView.image = UIImage(named: metadata.iconName)
            } else {
                imageView.image = UIImage(named: "file")
            }
        }
        favorite.setNeedsUpdateConstraints()
        favorite.layoutIfNeeded()
        fileName.text = metadata.fileNameView
        fileName.textColor = NCBrandColor.shared.label
        let starColor = metadata.favorite ? NCBrandColor.shared.yellowFavorite : NCBrandColor.shared.systemGray
        favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: starColor, size: 24), for: .normal)
        info.textColor = NCBrandColor.shared.secondaryLabel
        info.text = CCUtility.transformedSize(metadata.size) + ", " + CCUtility.dateDiff(metadata.date as Date)
    }
}
