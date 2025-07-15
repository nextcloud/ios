// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-FileCopyrightText: 2019 Philippe Weidmann
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCIntroCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!

    var indexPath = IndexPath()
}
