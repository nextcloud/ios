//
//  NCOfflineHeaderFooter.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/10/2018.
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

class NCOfflineSectionHeaderMenu: UICollectionReusableView {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonOrderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCOfflineHeaderDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(NCBrandColor.sharedInstance.icon, for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.seperator
    }
    
    func setTitleOrder(datasourceSorted: String, datasourceAscending: Bool) {
        
        // Order (∨∧▽△)
        var title = ""
        
        switch datasourceSorted {
        case "fileName":
            if datasourceAscending == true { title = NSLocalizedString("_order_by_name_a_z_", comment: "") }
            if datasourceAscending == false { title = NSLocalizedString("_order_by_name_z_a_", comment: "") }
        case "date":
            if datasourceAscending == false { title = NSLocalizedString("_order_by_date_more_recent_", comment: "") }
            if datasourceAscending == true { title = NSLocalizedString("_order_by_date_less_recent_", comment: "") }
        case "size":
            if datasourceAscending == true { title = NSLocalizedString("_order_by_size_smallest_", comment: "") }
            if datasourceAscending == false { title = NSLocalizedString("_order_by_size_largest_", comment: "") }
        default:
            title = NSLocalizedString("_order_by_", comment: "") + " " + datasourceSorted
        }
        
        title = title + "  ▽"
        let size = title.size(withAttributes:[.font: buttonOrder.titleLabel?.font as Any])
        
        buttonOrder.setTitle(title, for: .normal)
        buttonOrderWidthConstraint.constant = size.width + 5
    }
    
    func setStatusButton(count: Int) {
        
        if count == 0 {
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
        delegate?.tapMoreHeader(sender: sender)
    }
    
    @IBAction func touchUpInsideSwitch(_ sender: Any) {
        delegate?.tapSwitchHeader(sender: sender)
    }
    
    @IBAction func touchUpInsideOrder(_ sender: Any) {
        delegate?.tapOrderHeader(sender: sender)
    }
}

protocol NCOfflineHeaderDelegate {
    func tapSwitchHeader(sender: Any)
    func tapMoreHeader(sender: Any)
    func tapOrderHeader(sender: Any)
}

class NCOfflineSectionHeader: UICollectionReusableView {
    
    @IBOutlet weak var labelSection: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

class NCOfflineFooter: UICollectionReusableView {
    
    @IBOutlet weak var labelFooter: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        
        labelFooter.textColor = NCBrandColor.sharedInstance.icon
    }
    
    func setTitleLabelFooter(sectionDatasource: CCSectionDataSourceMetadata) {
        
        var foldersText = ""
        var filesText = ""
        
        if sectionDatasource.directories > 1 {
            foldersText = "\(sectionDatasource.directories) " + NSLocalizedString("_folders_", comment: "")
        } else if sectionDatasource.directories == 1 {
            foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
        }
        
        if sectionDatasource.files > 1 {
            filesText = "\(sectionDatasource.files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(sectionDatasource.totalSize)
        } else if sectionDatasource.files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(sectionDatasource.totalSize)
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
