//
//  NCSectionFirstHeaderEmptyData.swift
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
import RealmSwift

protocol NCSectionFirstHeaderEmptyDataDelegate: AnyObject {
}

class NCSectionFirstHeaderEmptyData: UICollectionReusableView {
    @IBOutlet weak var viewTransfer: UIView!
    @IBOutlet weak var viewTransferHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageTransfer: UIImageView!
    @IBOutlet weak var labelTransfer: UILabel!
    @IBOutlet weak var transferSeparatorBottom: UIView!
    @IBOutlet weak var transferSeparatorBottomHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTitle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!

    weak var delegate: NCSectionFirstHeaderEmptyDataDelegate?

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

        imageTransfer.tintColor = NCBrandColor.shared.iconImageColor
        imageTransfer.image = NCUtility().loadImage(named: "icloud.and.arrow.up")

        transferSeparatorBottom.backgroundColor = .separator
        transferSeparatorBottomHeightConstraint.constant = 0.5

        emptyImage.image = nil
        emptyTitle.text = ""
        emptyDescription.text = ""
    }

    // MARK: -

    func setContent(emptyImage: UIImage?,
                    emptyTitle: String?,
                    emptyDescription: String?,
                    heightHeaderTransfer: CGFloat,
                    headerTransferIsHidden: Bool,
                    delegate: NCSectionFirstHeaderEmptyDataDelegate?) {
        self.delegate = delegate
        self.emptyImage.image = emptyImage
        self.emptyTitle.text = emptyTitle
        self.emptyDescription.text = emptyDescription

        setViewTransfer(isHidden: headerTransferIsHidden, height: heightHeaderTransfer)
    }

    func setViewTransfer(isHidden: Bool, height: CGFloat) {
        viewTransfer.isHidden = isHidden

        if isHidden {
            viewTransferHeightConstraint.constant = 0
        } else {
            viewTransferHeightConstraint.constant = height
            if NCTransferProgress.shared.haveUploadInForeground() {
                labelTransfer.text = String(format: NSLocalizedString("_upload_foreground_msg_", comment: ""), NCBrandOptions.shared.brand)
            } else {
                labelTransfer.text = NSLocalizedString("_upload_background_msg_", comment: "")
            }
        }
    }
}
