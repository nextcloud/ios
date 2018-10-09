//
//  NCTrashHeader.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation

class NCTrashHeader: UICollectionReusableView {
    
    @IBOutlet weak var tapMore: UIImageView!
    @IBOutlet weak var separator: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        tapMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trashMore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
        
        let tapGestureMore = UITapGestureRecognizer(target: self, action: #selector(NCTrashHeader.tapMore(sender:)))
        addGestureRecognizer(tapGestureMore)
        tapGestureMore.numberOfTapsRequired = 1
        tapMore.isUserInteractionEnabled = true
        tapMore.addGestureRecognizer(tapGestureMore)
    }
    
    @objc func tapMore(sender: UITapGestureRecognizer) {
        print("tap header more")
    }
}
