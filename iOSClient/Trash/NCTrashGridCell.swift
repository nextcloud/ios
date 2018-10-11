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
    
    @IBOutlet weak var restore: UIImageView!

    @IBOutlet weak var labelTitle: UILabel!

    @IBOutlet weak var more: UIImageView!

    var delegate: NCTrashGridDelegate?
    
    var fileID = ""

    override func awakeFromNib() {
        super.awakeFromNib()
       
        restore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
                
        let tapGestureRestore = UITapGestureRecognizer(target: self, action: #selector(NCTrashGridCell.tapRestore(sender:)))
        addGestureRecognizer(tapGestureRestore)
        tapGestureRestore.numberOfTapsRequired = 1
        restore.isUserInteractionEnabled = true
        restore.addGestureRecognizer(tapGestureRestore)
        
        let tapGestureMore = UITapGestureRecognizer(target: self, action: #selector(NCTrashGridCell.tapMore(sender:)))
        addGestureRecognizer(tapGestureMore)
        tapGestureMore.numberOfTapsRequired = 1
        more.isUserInteractionEnabled = true
        more.addGestureRecognizer(tapGestureMore)
    }
    
    @objc func tapRestore(sender: UITapGestureRecognizer) {
        delegate?.tapRestoreItem(with: fileID)
    }
    @objc func tapMore(sender: UITapGestureRecognizer) {
        delegate?.tapMoreItem(with: fileID)
    }
}

protocol NCTrashGridDelegate {
    func tapRestoreItem(with fileID: String)
    func tapMoreItem(with fileID: String)
}
