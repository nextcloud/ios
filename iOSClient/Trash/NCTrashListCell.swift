//
//  NCTrashListCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation
import UIKit

class NCTrashListCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    public func configure(with image: UIImage?, title: String, info: String) {
        imageView.image = image
        labelTitle.text = title
        labelInfo.text = info
    }
}
