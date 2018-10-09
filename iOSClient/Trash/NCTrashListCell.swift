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
    @IBOutlet weak var restore: UIImageView!
    @IBOutlet weak var more: UIImageView!
    @IBOutlet weak var separator: UIView!

    
    var delegate: NCTrashListDelegate?
    
    var fileID = ""

    override func awakeFromNib() {
        super.awakeFromNib()
       
        restore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "restore"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
        more.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.icon)
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
        
        let tapGestureRestore = UITapGestureRecognizer(target: self, action: #selector(NCTrashListCell.tapRestore(sender:)))
        addGestureRecognizer(tapGestureRestore)
        tapGestureRestore.numberOfTapsRequired = 1
        restore.isUserInteractionEnabled = true
        restore.addGestureRecognizer(tapGestureRestore)
        
        let tapGestureMore = UITapGestureRecognizer(target: self, action: #selector(NCTrashListCell.tapMore(sender:)))
        addGestureRecognizer(tapGestureMore)
        tapGestureMore.numberOfTapsRequired = 1
        more.isUserInteractionEnabled = true
        more.addGestureRecognizer(tapGestureMore)
    }
    
    public func configure(with fileID: String, image: UIImage?, title: String, info: String) {

        self.fileID = fileID

        imageView.image = image
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
