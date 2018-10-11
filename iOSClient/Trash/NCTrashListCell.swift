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
    
    @IBOutlet weak var imageItem: UIImageView!
    
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    
    @IBOutlet weak var more: UIImageView!
    @IBOutlet weak var restore: UIImageView!

    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonRestore: UIButton!
    
    @IBOutlet weak var separator: UIView!

    var delegate: NCTrashListDelegate?
    
    var fileID = ""

    override func awakeFromNib() {
        super.awakeFromNib()
       
        restore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreItem(with: fileID)
    }
    
    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreItem(with: fileID)
    }
}

protocol NCTrashListDelegate {
    func tapRestoreItem(with fileID: String)
    func tapMoreItem(with fileID: String)
}
