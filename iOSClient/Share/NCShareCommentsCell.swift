//
//  NCShareComments.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/07/2019.
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
import NextcloudKit

// MARK: - NCShareCommentsCell

class NCShareCommentsCell: UITableViewCell, NCCellProtocol {

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelUser: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!
    @IBOutlet weak var labelDate: UILabel!
    @IBOutlet weak var labelMessage: UILabel!

    private var index = IndexPath()

    var tableComments: tableComments?
    weak var delegate: NCShareCommentsCellDelegate?

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var fileAvatarImageView: UIImageView? {
        return imageItem
    }
    var fileUser: String? {
        get { return tableComments?.actorId }
        set {}
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAvatarImage))
        imageItem?.addGestureRecognizer(tapGesture)
    }

    @objc func tapAvatarImage(_ sender: UITapGestureRecognizer) {
        self.delegate?.showProfile(with: tableComments, sender: sender)
    }

    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableComments, sender: sender)
    }
}

protocol NCShareCommentsCellDelegate: AnyObject {
    func tapMenu(with tableComments: tableComments?, sender: Any)
    func showProfile(with tableComment: tableComments?, sender: Any)
}
