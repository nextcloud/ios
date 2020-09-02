//
//  NCTrashSectionHeaderFooter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

class NCTrashSectionHeaderMenu: UICollectionReusableView {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonOrderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCTrashSectionHeaderMenuDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(NCBrandColor.sharedInstance.brandElement, for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.separator
        backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
    
    func setTitleSorted(datasourceTitleButton: String) {
        
        let title = NSLocalizedString(datasourceTitleButton, comment: "")
        let size = title.size(withAttributes:[.font: buttonOrder.titleLabel?.font as Any])
        
        buttonOrder.setTitle(title, for: .normal)
        buttonOrderWidthConstraint.constant = size.width + 5
    }
    
    func setStatusButton(datasource: [tableTrash]) {
        
        if datasource.count == 0 {
            buttonSwitch.isEnabled = false
            buttonOrder.isEnabled = false
            buttonMore.isEnabled = false
        } else {
            buttonSwitch.isEnabled = true
            buttonOrder.isEnabled = true
            buttonMore.isEnabled = true
        }
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

protocol NCTrashSectionHeaderMenuDelegate {
    func tapSwitchHeaderMenu(sender: Any)
    func tapMoreHeaderMenu(sender: Any)
    func tapOrderHeaderMenu(sender: Any)
}

class NCTrashSectionFooter: UICollectionReusableView {
    
    @IBOutlet weak var labelFooter: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        labelFooter.textColor = NCBrandColor.sharedInstance.icon
    }
    
    func setTitleLabelFooter(datasource: [tableTrash]) {
        
        var folders: Int = 0, foldersText = ""
        var files: Int = 0, filesText = ""
        var size: Double = 0
        
        for record: tableTrash in datasource {
            if record.directory {
                folders += 1
            } else {
                files += 1
                size = size + record.size
            }
        }
        
        if folders > 1 {
            foldersText = "\(folders) " + NSLocalizedString("_folders_", comment: "")
        } else if folders == 1 {
            foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
        }
        
        if files > 1 {
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(size)
        }
        
        if foldersText == "" {
            labelFooter.text = filesText
        } else if filesText == "" {
            labelFooter.text = foldersText
        } else {
            labelFooter.text = foldersText + ", " + filesText
        }
    }
}
