// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import MarkdownKit
import RealmSwift

class NCSectionFirstHeaderEmptyData: UICollectionReusableView {
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTitle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!

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

        // FONT SCALLED
        //
        let scaledFontHeadline = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: UIFont.preferredFont(forTextStyle: .headline), maximumPointSize: 25)
        emptyTitle.font = scaledFontHeadline
        emptyTitle.adjustsFontForContentSizeCategory = true

        let scaledFontCaption1 = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: UIFont.preferredFont(forTextStyle: .caption1), maximumPointSize: 15)
        emptyDescription.font = scaledFontCaption1
        emptyDescription.adjustsFontForContentSizeCategory = true
    }

    // MARK: -

    func setContent(emptyImage: UIImage?,
                    emptyTitle: String?,
                    emptyDescription: String?) {
        self.emptyImage.image = emptyImage
        self.emptyTitle.text = emptyTitle
        self.emptyDescription.text = emptyDescription
    }
}
