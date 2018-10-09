//
//  NCTrashHeader.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation

class NCTrashHeader: UICollectionReusableView {
    
    @IBOutlet weak var tapSwitch: UIImageView!
    @IBOutlet weak var tapMore: UIImageView!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCTrashHeaderDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        tapMore.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "trashMore"), multiplier: 2, color: NCBrandColor.sharedInstance.optionItem)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
        
        let tapGestureSwitch = UITapGestureRecognizer(target: self, action: #selector(NCTrashHeader.tapSwitch(sender:)))
        addGestureRecognizer(tapGestureSwitch)
        tapGestureSwitch.numberOfTapsRequired = 1
        tapSwitch.isUserInteractionEnabled = true
        tapSwitch.addGestureRecognizer(tapGestureSwitch)
        
        let tapGestureMore = UITapGestureRecognizer(target: self, action: #selector(NCTrashHeader.tapMore(sender:)))
        addGestureRecognizer(tapGestureMore)
        tapGestureMore.numberOfTapsRequired = 1
        tapMore.isUserInteractionEnabled = true
        tapMore.addGestureRecognizer(tapGestureMore)
    }
    
    @objc func tapSwitch(sender: UITapGestureRecognizer) {
        delegate?.tapSwitchHeader()
    }
    @objc func tapMore(sender: UITapGestureRecognizer) {
        delegate?.tapMoreHeader()
    }
}

protocol NCTrashHeaderDelegate {
    func tapSwitchHeader()
    func tapMoreHeader()
}

