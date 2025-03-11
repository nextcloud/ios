//
//  NCTransferCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2020.
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

class NCTransferCell: UICollectionViewCell, UIGestureRecognizerDelegate, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelPath: UILabel!
    @IBOutlet weak var labelStatus: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!

    private var ocId = ""
    private var ocIdTransfer = ""
    private var user = ""

    weak var delegate: NCTransferCellDelegate?

    var fileOcId: String? {
        get { return ocId }
        set { ocId = newValue ?? "" }
    }
    var fileOcIdTransfer: String? {
        get { return ocIdTransfer }
        set { ocIdTransfer = newValue ?? "" }
    }
    var filePreviewImageView: UIImageView? {
        get { return imageItem }
        set { imageItem = newValue }
    }
    var fileStatusImage: UIImageView? {
        get { return imageStatus }
        set { imageStatus = newValue }
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }
    var fileTitleLabel: UILabel? {
        get { return labelTitle }
        set { labelTitle = newValue }
    }
    var fileInfoLabel: UILabel? {
        get { return labelInfo }
        set { labelInfo = newValue }
    }
    var fileProgressView: UIProgressView? {
        get { return progressView }
        set { progressView = newValue }
    }
    var fileMoreImage: UIImageView? {
        get { return imageMore }
        set { imageMore = newValue }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        isAccessibilityElement = true

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        progressView.tintColor = NCBrandColor.shared.iconImageColor
        progressView.transform = CGAffineTransform(scaleX: 1.0, y: 0.5)
        progressView.trackTintColor = .clear

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)

        let longPressedGestureMore = UILongPressGestureRecognizer(target: self, action: #selector(longPressInsideMore(gestureRecognizer:)))
        longPressedGestureMore.minimumPressDuration = 0.5
        longPressedGestureMore.delegate = self
        longPressedGestureMore.delaysTouchesBegan = true
        buttonMore.addGestureRecognizer(longPressedGestureMore)

        separator.backgroundColor = .separator
        separatorHeightConstraint.constant = 0.5

        labelTitle.text = ""
        labelInfo.text = ""
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
    }

    @IBAction func touchUpInsideShare(_ sender: Any) {
        delegate?.tapShareListItem(with: ocId, ocIdTransfer: ocIdTransfer, sender: sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: ocId, ocIdTransfer: ocIdTransfer, image: imageItem.image, sender: sender)
    }

    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressMoreListItem(with: ocId, ocIdTransfer: ocIdTransfer, gestureRecognizer: gestureRecognizer)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressListItem(with: ocId, ocIdTransfer: ocIdTransfer, gestureRecognizer: gestureRecognizer)
    }

    func hideButtonMore(_ status: Bool) {
        imageMore.isHidden = status
        buttonMore.isHidden = status
    }

    func setProgress(progress: Float) {
        progressView.progress = progress
        if progress > 0.0 {
            progressView.isHidden = false
        } else {
            progressView.isHidden = true
        }
    }

    func setButtonMore(image: UIImage) {
        imageMore.image = image
        self.accessibilityCustomActions = [
            UIAccessibilityCustomAction(
                name: NSLocalizedString("_cancel_", comment: ""),
                target: self,
                selector: #selector(touchUpInsideMore))
        ]
    }

    func writeInfoDateSize(date: NSDate, size: Int64) {
        labelInfo.text = NCUtility().getRelativeDateTitle(date as Date) + " · " + NCUtilityFileSystem().transformedSize(size)
    }

    func setIconOutlines() {
        if imageStatus.image != nil {
            imageStatus.makeCircularBackground(withColor: .systemBackground)
        } else {
            imageStatus.backgroundColor = .clear
        }
    }
}

protocol NCTransferCellDelegate: AnyObject {
    func tapShareListItem(with ocId: String, ocIdTransfer: String, sender: Any)
    func tapMoreListItem(with ocId: String, ocIdTransfer: String, image: UIImage?, sender: Any)
    func longPressMoreListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressListItem(with ocId: String, ocIdTransfer: String, gestureRecognizer: UILongPressGestureRecognizer)
}
