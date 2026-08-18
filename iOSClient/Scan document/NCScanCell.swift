// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCScanCell: UICollectionViewCell, UIGestureRecognizerDelegate {

    @IBOutlet weak var customImageView: UIImageView!
    @IBOutlet weak var customLabel: UILabel!
    @IBOutlet weak var delete: UIButton!
    @IBOutlet weak var modify: UIButton!

    weak var delegate: NCScanCellCellDelegate?
    var index = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped(_:)))
        customImageView.addGestureRecognizer(tapGesture)
    }

    @IBAction func touchUpInsideDelete(_ sender: Any) {
        delegate?.delete(with: index, sender: sender)
    }

    @objc private func imageTapped(_ sender: Any) {
        delegate?.imageTapped(with: index, sender: sender)
    }
}

protocol NCScanCellCellDelegate: AnyObject {
    func delete(with index: Int, sender: Any)
    func imageTapped(with index: Int, sender: Any)
}
