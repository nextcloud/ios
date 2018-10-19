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
    @IBOutlet weak var imageItemLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageSelect: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    
    @IBOutlet weak var imageRestore: UIImageView!
    @IBOutlet weak var imageMore: UIImageView!

    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonRestore: UIButton!
    
    @IBOutlet weak var separator: UIView!

    var delegate: NCTrashListDelegate?
    
    var fileID = ""
    var indexPath = IndexPath()

    override func awakeFromNib() {
        super.awakeFromNib()
       
        imageRestore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        imageMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreItem(with: fileID, sender: sender)
    }
    
    @IBAction func touchUpInsideRestore(_ sender: Any) {
        delegate?.tapRestoreItem(with: fileID, sender: sender)
    }
}

protocol NCTrashListDelegate {
    func tapRestoreItem(with fileID: String, sender: Any)
    func tapMoreItem(with fileID: String, sender: Any)
}
