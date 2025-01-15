//
//  NCRecommendationsCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/01/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import UIKit
import NextcloudKit

protocol NCRecommendationsCellDelegate: AnyObject {
    func touchUpInsideButtonMenu(with metadata: tableMetadata, image: UIImage?)
    func longPressGestureRecognized(with metadata: tableMetadata, image: UIImage?)
}

class NCRecommendationsCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var labelFilename: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    @IBOutlet weak var buttonMenu: UIButton!

    var delegate: NCRecommendationsCellDelegate?
    var metadata: tableMetadata = tableMetadata()
    var recommendedFiles: tableRecommendedFiles = tableRecommendedFiles()

    override func awakeFromNib() {
        super.awakeFromNib()
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

        if metadata.hasPreview, metadata.classFile == NKCommon.TypeClassFile.document.rawValue {
            image.layer.cornerRadius = 10
            image.layer.masksToBounds = true
            image.layer.borderWidth = 0.5
            image.layer.borderColor = UIColor.separator.cgColor
        }

        let longPressedGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPress(gestureRecognizer:)))
        longPressedGesture.minimumPressDuration = 0.5
        longPressedGesture.delegate = self
        longPressedGesture.delaysTouchesBegan = true
        self.addGestureRecognizer(longPressedGesture)
    }

    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {
        self.delegate?.touchUpInsideButtonMenu(with: self.metadata, image: image.image)
    }

    @objc func longPress(gestureRecognizer: UILongPressGestureRecognizer) {
        self.delegate?.longPressGestureRecognized(with: metadata, image: image.image)
    }
}
