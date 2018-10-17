//
//  NCTrashHeaderMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation

class NCTrashHeaderMenu: UICollectionReusableView {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCTrashHeaderMenuDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "moreBig"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreHeaderMenu()
    }
    
    @IBAction func touchUpInsideSwitch(_ sender: Any) {
        delegate?.tapSwitchHeaderMenu()
    }
}

protocol NCTrashHeaderMenuDelegate {
    func tapSwitchHeaderMenu()
    func tapMoreHeaderMenu()
}

class NCTrashFooterMenu: UICollectionReusableView {
    
    @IBOutlet weak var labelFooter: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
}
