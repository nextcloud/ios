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
    private var avatarButton: UIButton!

    var tableComments: tableComments?
    weak var delegate: NCShareCommentsCellDelegate?

    var indexPath: IndexPath {
        get { return index }
        set { index = newValue }
    }
    var avatarImageView: UIImageView? {
        return imageItem
    }
    var fileUser: String? {
        get { return tableComments?.actorId }
        set {}
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        avatarButton = UIButton(type: .system)
        avatarButton.translatesAutoresizingMaskIntoConstraints = false
        avatarButton.backgroundColor = .clear
        contentView.addSubview(avatarButton)
        NSLayoutConstraint.activate([
            avatarButton.topAnchor.constraint(equalTo: imageItem.topAnchor),
            avatarButton.bottomAnchor.constraint(equalTo: imageItem.bottomAnchor),
            avatarButton.leadingAnchor.constraint(equalTo: imageItem.leadingAnchor),
            avatarButton.trailingAnchor.constraint(equalTo: imageItem.trailingAnchor)
        ])
        avatarButton.showsMenuAsPrimaryAction = true
    }

    func configureAvatarMenu() {
        guard let tableComments = tableComments else {
            avatarButton.menu = nil
            return
        }
        avatarButton.menu = delegate?.profileMenu(with: tableComments)
    }

    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: tableComments, sender: sender)
    }
}

protocol NCShareCommentsCellDelegate: AnyObject {
    func tapMenu(with tableComments: tableComments?, sender: Any)
    func profileMenu(with tableComment: tableComments?) -> UIMenu?
}
