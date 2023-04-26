//
//  NCScanCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/08/18.
//  Copyright (c) 2018 Marino Faggiana. All rights reserved.
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

class NCScanCell: UICollectionViewCell {

    @IBOutlet weak var customImageView: UIImageView!
    @IBOutlet weak var customLabel: UILabel!
    @IBOutlet weak var delete: UIButton!
    @IBOutlet weak var rotate: UIButton!

    weak var delegate: NCScanCellCellDelegate?
    var index = 0

    @IBAction func touchUpInsideDelete(_ sender: Any) {
        delegate?.delete(with: index, sender: sender)
    }

    @IBAction func touchUpInsideRotate(_ sender: Any) {
        delegate?.rotate(with: index, sender: sender)
    }
}

protocol NCScanCellCellDelegate: AnyObject {
    func delete(with index: Int, sender: Any)
    func rotate(with index: Int, sender: Any)
}
