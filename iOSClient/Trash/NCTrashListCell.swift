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
    
    @IBOutlet weak var restore: UIImageView!
    @IBOutlet weak var tapRestore: UIImageView!

    @IBOutlet weak var more: UIImageView!
    @IBOutlet weak var tapMore: UIImageView!

    @IBOutlet weak var separator: UIView!

    
    var delegate: NCTrashListDelegate?
    
    var fileID = ""

    override func awakeFromNib() {
        super.awakeFromNib()
       
        restore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trashRestore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trashMore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
        
        let tapGestureRestore = UITapGestureRecognizer(target: self, action: #selector(NCTrashListCell.tapRestore(sender:)))
        addGestureRecognizer(tapGestureRestore)
        tapGestureRestore.numberOfTapsRequired = 1
        tapRestore.isUserInteractionEnabled = true
        tapRestore.addGestureRecognizer(tapGestureRestore)
        
        let tapGestureMore = UITapGestureRecognizer(target: self, action: #selector(NCTrashListCell.tapMore(sender:)))
        addGestureRecognizer(tapGestureMore)
        tapGestureMore.numberOfTapsRequired = 1
        tapMore.isUserInteractionEnabled = true
        tapMore.addGestureRecognizer(tapGestureMore)
    }
    
    public func configure(with fileID: String, image: UIImage?, title: String, info: String) {

        self.fileID = fileID

        imageItem.image = image
        labelTitle.text = title
        labelInfo.text = info
    }
    
    @objc func tapRestore(sender: UITapGestureRecognizer) {
        delegate?.tapRestoreDelegate(with: fileID)
    }
    @objc func tapMore(sender: UITapGestureRecognizer) {
        delegate?.tapMoreDelegate(with: fileID)
    }
}

protocol NCTrashListDelegate {
    func tapRestoreDelegate(with fileID: String)
    func tapMoreDelegate(with fileID: String)
}
