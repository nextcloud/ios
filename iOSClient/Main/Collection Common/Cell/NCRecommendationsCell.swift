// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

protocol NCRecommendationsCellDelegate: AnyObject {
    func onMenuIntent(with metadata: tableMetadata?)
    func contextMenu(with metadata: tableMetadata?, button: UIButton, sender: Any)
}

class NCRecommendationsCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var labelFilename: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var buttonMore: UIButton!

    var delegate: NCRecommendationsCellDelegate?
    var recommendedFiles: tableRecommendedFiles = tableRecommendedFiles()

    var metadata: tableMetadata? {
        didSet {
            delegate?.contextMenu(with: metadata, button: buttonMore, sender: self) /* preconfigure UIMenu with each metadata */
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let tapObserver = UITapGestureRecognizer(target: self, action: #selector(handleTapObserver(_:)))
        tapObserver.cancelsTouchesInView = false
        tapObserver.delegate = self
        contentView.addGestureRecognizer(tapObserver)

        initCell()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        initCell()
    }

    func initCell() {
        let imageButton = UIImage(systemName: "ellipsis.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .thin))?.applyingSymbolConfiguration(UIImage.SymbolConfiguration(paletteColors: [.black, .white]))

        buttonMore.setImage(imageButton, for: .normal)
        buttonMore.layer.shadowColor = UIColor.black.cgColor
        buttonMore.layer.shadowOpacity = 0.2
        buttonMore.layer.shadowOffset = CGSize(width: 2, height: 2)
        buttonMore.layer.shadowRadius = 4

        image.image = nil
        labelFilename.text = ""
        labelInfo.text = ""

        buttonMore.menu = nil
        buttonMore.showsMenuAsPrimaryAction = true
        contentView.bringSubviewToFront(buttonMore)
    }

    @objc private func handleTapObserver(_ g: UITapGestureRecognizer) {
        let location = g.location(in: contentView)

        if buttonMore.frame.contains(location) {
            delegate?.onMenuIntent(with: metadata)
        }
    }

    func setImageCorner(withBorder: Bool) {
        image.layer.cornerRadius = 10
        image.layer.masksToBounds = true
        if withBorder {
            image.layer.borderWidth = 0.5
            image.layer.borderColor = UIColor.separator.cgColor
        } else {
            image.layer.borderWidth = 0
            image.layer.borderColor = UIColor.clear.cgColor
        }
    }
}
