// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

class NCSectionHeader: UICollectionReusableView {
    @IBOutlet weak var labelSection: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        self.backgroundColor = UIColor.clear
        self.labelSection.text = ""
    }

    func setContent(text: String) {
        self.labelSection.text = text
    }
}
