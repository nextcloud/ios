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

    override func prepareForReuse() {
        super.prepareForReuse()
        
        imageView.image = nil
        labelTitle.text = ""
        labelInfo.text = ""
    }
    
}
