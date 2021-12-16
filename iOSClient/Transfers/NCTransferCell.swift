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
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelPath: UILabel!
    @IBOutlet weak var labelStatus: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var imageMore: UIImageView!
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var separatorHeightConstraint: NSLayoutConstraint!

    private var objectId = ""
    private var user = ""

    weak var delegate: NCTransferCellDelegate?
    var indexPath = IndexPath()
    var namedButtonMore = ""

    var fileAvatarImageView: UIImageView? {
        get {
            return nil
        }
    }
    var fileObjectId: String? {
        get {
            return objectId
        }
        set {
            objectId = newValue ?? ""
        }
    }
    var filePreviewImageView: UIImageView? {
        get {
            return imageItem
        }
    }
    var fileUser: String? {
        get {
            return user
        }
        set {
            user = newValue ?? ""
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        imageItem.layer.cornerRadius = 6
        imageItem.layer.masksToBounds = true

        progressView.tintColor = NCBrandColor.shared.brandElement
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

        separator.backgroundColor = NCBrandColor.shared.separator
        separatorHeightConstraint.constant = 0.5
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageItem.backgroundColor = nil
    }

    @IBAction func touchUpInsideShare(_ sender: Any) {
        delegate?.tapShareListItem(with: objectId, sender: sender)
    }

    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreListItem(with: objectId, namedButtonMore: namedButtonMore, image: imageItem.image, sender: sender)
    }

    @objc func longPressInsideMore(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressMoreListItem(with: objectId, namedButtonMore: namedButtonMore, gestureRecognizer: gestureRecognizer)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        delegate?.longPressListItem(with: objectId, gestureRecognizer: gestureRecognizer)
    }

    func setButtonMore(named: String, image: UIImage) {
        namedButtonMore = named
        imageMore.image = image
    }
}

protocol NCTransferCellDelegate: AnyObject {
    func tapShareListItem(with objectId: String, sender: Any)
    func tapMoreListItem(with objectId: String, namedButtonMore: String, image: UIImage?, sender: Any)
    func longPressMoreListItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer)
    func longPressListItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer)
}
