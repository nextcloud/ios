// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMediaSectionHeader: UICollectionReusableView {
    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundColor = .clear

        titleLabel.text = nil
        titleLabel.textColor = .white

        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.9
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 1)
        titleLabel.layer.masksToBounds = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        titleLabel.text = nil
    }
}
