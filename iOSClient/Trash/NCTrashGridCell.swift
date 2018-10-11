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
    @IBOutlet weak var restore: UIImageView!

    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonRestore: UIButton!

    
    var delegate: NCTrashGridDelegate?
    
    var fileID = ""

    override func awakeFromNib() {
        super.awakeFromNib()
       
        restore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreItem(with: fileID)
    }
    
    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreItem(with: fileID)
    }
}

protocol NCTrashGridDelegate {
    func tapRestoreItem(with fileID: String)
    func tapMoreItem(with fileID: String)
}
