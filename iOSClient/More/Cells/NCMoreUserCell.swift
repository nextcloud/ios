//
//  NCMoreUserCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
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

import Foundation
import MarqueeLabel

class NCMoreUserCell: BaseNCMoreCell {
    @IBOutlet weak var displayName: UILabel!
    @IBOutlet weak var avatar: UIImageView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var status: MarqueeLabel!

    static let reuseIdentifier = "NCMoreUserCell"

    static func fromNib() -> UINib {
        return UINib(nibName: "NCMoreUserCell", bundle: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        icon.makeCircularBackground(withColor: .systemBackground)
    }
}
