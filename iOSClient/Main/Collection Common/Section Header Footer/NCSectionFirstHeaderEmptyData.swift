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
        emptyImage.image = nil
        emptyTitle.text = ""
        emptyDescription.text = ""
    }

    // MARK: -

    func setContent(emptyImage: UIImage?,
                    emptyTitle: String?,
                    emptyDescription: String?,
                    delegate: NCSectionFirstHeaderEmptyDataDelegate?) {
        self.delegate = delegate
        self.emptyImage.image = emptyImage
        self.emptyTitle.text = emptyTitle
        self.emptyDescription.text = emptyDescription
    }
}
