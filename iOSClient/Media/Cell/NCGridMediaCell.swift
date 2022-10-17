//
//  NCGridMediaCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/02/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
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

class NCGridMediaCell: UICollectionViewCell, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!

    private var objectId: String = ""
    private var user: String = ""

    var date: Date?

    var filePreviewImageView: UIImageView? {
        get { return imageItem }
        set {}
    }
    var fileObjectId: String? {
        get { return objectId }
        set { objectId = newValue ?? "" }
    }
    var fileUser: String? {
        get { return user }
        set { user = newValue ?? "" }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }

    func initCell() {
        imageItem.backgroundColor = .secondarySystemBackground
        imageStatus.image = nil
        imageItem.image = nil
    }

    func selectMode(_ status: Bool) {
        if status {
            imageSelect.isHidden = false
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }

    func selected(_ status: Bool) {
        if status {
            imageSelect.image = NCBrandColor.cacheImages.checkedYes
            imageVisualEffect.isHidden = false
            imageVisualEffect.alpha = 0.4
        } else {
            imageSelect.isHidden = true
            imageVisualEffect.isHidden = true
        }
    }
}
