//
//  NCRecommendationsCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/01/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import UIKit

protocol NCRecommendationsCellDelegate: AnyObject {
    func onMenuIntent(with ocId: String)
    func contextMenu(with metadata: tableMetadata, button: UIButton, sender: Any)
}

class NCRecommendationsCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var labelFilename: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!

    var delegate: NCRecommendationsCellDelegate?
    var metadata: tableMetadata = tableMetadata()
    var recommendedFiles: tableRecommendedFiles = tableRecommendedFiles()
    var id: String = "" { didSet { delegate?.contextMenu(with: metadata, button: buttonMenu, sender: self) /* preconfigure UIMenu with each id set */ } }

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

        buttonMenu.setImage(imageButton, for: .normal)
        buttonMenu.layer.shadowColor = UIColor.black.cgColor
        buttonMenu.layer.shadowOpacity = 0.2
        buttonMenu.layer.shadowOffset = CGSize(width: 2, height: 2)
        buttonMenu.layer.shadowRadius = 4

        image.image = nil
        labelFilename.text = ""
        labelInfo.text = ""

        buttonMenu.menu = nil
        buttonMenu.showsMenuAsPrimaryAction = true
        contentView.bringSubviewToFront(buttonMenu)
    }

    @objc private func handleTapObserver(_ g: UITapGestureRecognizer) {
        let location = g.location(in: contentView)

        if buttonMenu.frame.contains(location) {
            delegate?.onMenuIntent(with: metadata.ocId)
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
