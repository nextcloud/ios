//
//  NCRecommendationsCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/01/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import UIKit

protocol NCRecommendationsCellDelegate: AnyObject {
    func touchUpInsideButtonMenu(with metadata: tableMetadata, recommendedFiles: tableRecommendedFiles, image: UIImage?)
}

class NCRecommendationsCell: UICollectionViewCell {
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
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true

        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray5.cgColor
    }

    @IBAction func touchUpInsideButtonMenu(_ sender: Any) {
        self.delegate?.touchUpInsideButtonMenu(with: self.metadata, recommendedFiles: self.recommendedFiles, image: image.image)
    }
}
