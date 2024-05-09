//
//  NCSectionHeaderEmptyData.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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
import MarkdownKit

protocol NCSectionHeaderEmptyDataDelegate: AnyObject {
    func tapButtonTransfer(_ sender: Any)
}

class NCSectionHeaderEmptyData: UICollectionReusableView {

    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var buttonTransfer: UIButton!
    @IBOutlet weak var imageButtonTransfer: UIImageView!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var progressTransfer: UIProgressView!
    @IBOutlet weak var transferSeparatorBottom: UIView!
    @IBOutlet weak var transferSeparatorBottomHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTitle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!

    weak var delegate: NCSectionHeaderEmptyDataDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        initHeader()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initHeader()
    }

    func initHeader() {
        viewTransferHeightConstraint.constant = 0
        viewTransfer.isHidden = true
        buttonTransfer.backgroundColor = .clear
        buttonTransfer.setImage(nil, for: .normal)
        buttonTransfer.layer.cornerRadius = 6
        buttonTransfer.layer.masksToBounds = true
        imageButtonTransfer.image = UIImage(systemName: "stop.circle")
        imageButtonTransfer.tintColor = .white
        labelTransfer.text = ""
        progressTransfer.progress = 0
        progressTransfer.tintColor = NCBrandColor.shared.brand
        progressTransfer.trackTintColor = NCBrandColor.shared.brand.withAlphaComponent(0.2)
        transferSeparatorBottom.backgroundColor = .separator
        transferSeparatorBottomHeightConstraint.constant = 0.5
        emptyImage.image = nil
        emptyTitle.text = ""
        emptyDescription.text = ""
    }

    // MARK: - Action

    @IBAction func touchUpTransfer(_ sender: Any) {
       delegate?.tapButtonTransfer(sender)
    }

    // MARK: - Transfer

    func setViewTransfer(isHidden: Bool, ocId: String? = nil, text: String? = nil, progress: Float? = nil) {

        labelTransfer.text = text
        viewTransfer.isHidden = isHidden
        progressTransfer.progress = 0

        if isHidden {
            viewTransferHeightConstraint.constant = 0
        } else {
            var image: UIImage?
            if let ocId,
               let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
                image = NCUtility().createFilePreviewImage(ocId: metadata.ocId, etag: metadata.etag, fileNameView: metadata.fileNameView, classFile: metadata.classFile, status: metadata.status, createPreviewMedia: true)?.darken()
                if image == nil {
                    image = NCUtility().loadImage(named: metadata.iconName)
                    buttonTransfer.backgroundColor = .lightGray
                } else {
                    buttonTransfer.backgroundColor = .clear
                }
                buttonTransfer.setImage(image, for: .normal)
            }
            viewTransferHeightConstraint.constant = NCGlobal.shared.heightHeaderTransfer
            if let progress {
                progressTransfer.progress = progress
            }
        }
    }
}
