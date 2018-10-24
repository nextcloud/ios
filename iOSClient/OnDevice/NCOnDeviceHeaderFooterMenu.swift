//
//  NCOnDeviceHeaderFooterMenu.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

class NCOnDeviceHeaderMenu: UICollectionReusableView {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonOrderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCOnDeviceHeaderMenuDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(NCBrandColor.sharedInstance.icon, for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    @IBAction func touchUpInsideMore(_ sender: Any) {
        delegate?.tapMoreHeaderMenu(sender: sender)
    }
    
    @IBAction func touchUpInsideSwitch(_ sender: Any) {
        delegate?.tapSwitchHeaderMenu(sender: sender)
    }
    
    @IBAction func touchUpInsideOrder(_ sender: Any) {
        delegate?.tapOrderHeaderMenu(sender: sender)
    }
}

protocol NCOnDeviceHeaderMenuDelegate {
    func tapSwitchHeaderMenu(sender: Any)
    func tapMoreHeaderMenu(sender: Any)
    func tapOrderHeaderMenu(sender: Any)

}

class NCOnDeviceFooterMenu: UICollectionReusableView {
    
    @IBOutlet weak var labelFooter: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
    }
}
