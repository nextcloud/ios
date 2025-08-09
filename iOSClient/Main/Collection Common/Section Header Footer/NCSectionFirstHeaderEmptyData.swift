// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
