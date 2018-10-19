//
//  NCTrashGridCell.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/10/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation
import UIKit

class NCTrashGridCell: UICollectionViewCell {
    
    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var more: UIImageView!

    @IBOutlet weak var buttonMoreGrid: UIButton!

    var delegate: NCTrashGridDelegate?
    
    var fileID = ""
    var indexPath = IndexPath()

    override func awakeFromNib() {
        super.awakeFromNib()
       
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
    }
    
    @IBAction func touchUpInsideMoreGrid(_ sender: Any) {
        delegate?.tapMoreGridItem(with: fileID, sender: sender)
    }
}

protocol NCTrashGridDelegate {
    func tapMoreGridItem(with fileID: String, sender: Any)
}
