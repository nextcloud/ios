// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2019 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

class NCMediaCell: UICollectionViewCell {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var imageVisualEffect: UIVisualEffectView!
    @IBOutlet weak var imageSelect: UIImageView!
    @IBOutlet weak var imageStatus: UIImageView!

    var identifier: String = ""
    var date: Date?

    override func awakeFromNib() {
        super.awakeFromNib()
        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }

    func initCell() {
        imageStatus.image = nil
        image.image = nil

        imageVisualEffect.isHidden = false
        imageVisualEffect.effect = nil
        imageVisualEffect.alpha = 0
        imageVisualEffect.isUserInteractionEnabled = false
        imageVisualEffect.backgroundColor = UIColor.white.withAlphaComponent(0.2)
    }

    func selected(_ status: Bool, color: UIColor) {
        imageVisualEffect.alpha = status ? 1 : 0
        imageSelect.alpha = status ? 1 : 0
        imageSelect.image = NCImageCache.shared.getImageCheckedYes(color: color)
    }
}
