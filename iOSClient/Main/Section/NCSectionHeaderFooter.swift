//
//  NCSectionHeaderFooter.swift
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

class NCSectionHeaderMenu: UICollectionReusableView {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonOrderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewLabelSection: UIView!
    @IBOutlet weak var labelSection: UILabel!
    @IBOutlet weak var labelSectionHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCSectionHeaderMenuDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(NCBrandColor.sharedInstance.brandElement, for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), multiplier: 2, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        viewLabelSection.backgroundColor = NCBrandColor.sharedInstance.select
        separator.backgroundColor = NCBrandColor.sharedInstance.separator
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
    
    func setTitleSorted(datasourceTitleButton: String) {
        
        let title = NSLocalizedString(datasourceTitleButton, comment: "")
        let size = title.size(withAttributes:[.font: buttonOrder.titleLabel?.font as Any])
        
        buttonOrder.setTitle(title, for: .normal)
        buttonOrderWidthConstraint.constant = size.width + 5
    }
    
    func setTitleLabel(sectionDatasource: CCSectionDataSourceMetadata, section: Int) {
        
        var title = ""
        
        if sectionDatasource.sections.object(at: section) is String {
            title = sectionDatasource.sections.object(at: section) as! String
        }
        if sectionDatasource.sections.object(at: section) is Date {
            let titleDate = sectionDatasource.sections.object(at: section) as! Date
            title = CCUtility.getTitleSectionDate(titleDate)
        }
        
        if title.contains("download") {
            labelSection.text = NSLocalizedString("_title_section_download_", comment: "")
        } else if title.contains("upload") {
            labelSection.text = NSLocalizedString("_title_section_upload_", comment: "")
        } else {
            labelSection.text = NSLocalizedString(title, comment: "")
        }
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

protocol NCSectionHeaderMenuDelegate {
    func tapSwitchHeader(sender: Any)
    func tapMoreHeader(sender: Any)
    func tapOrderHeader(sender: Any)
}

class NCSectionHeader: UICollectionReusableView {
    
    @IBOutlet weak var labelSection: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = NCBrandColor.sharedInstance.select
    }
    
    func setTitleLabel(sectionDatasource: CCSectionDataSourceMetadata, section: Int) {
        
        var title = ""
        
        if sectionDatasource.sections.object(at: section) is String {
            title = sectionDatasource.sections.object(at: section) as! String
        }
        if sectionDatasource.sections.object(at: section) is Date {
            let titleDate = sectionDatasource.sections.object(at: section) as! Date
            title = CCUtility.getTitleSectionDate(titleDate)
        }
        
        if title.contains("download") {
            labelSection.text = NSLocalizedString("_title_section_download_", comment: "")
        } else if title.contains("upload") {
            labelSection.text = NSLocalizedString("_title_section_upload_", comment: "")
        } else {
            labelSection.text = NSLocalizedString(title, comment: "")
        }
    }
}

class NCSectionFooter: UICollectionReusableView {
    
    @IBOutlet weak var labelSection: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = UIColor.clear
        labelSection.textColor = NCBrandColor.sharedInstance.icon
    }
    
    func setTitleLabel(sectionDatasource: CCSectionDataSourceMetadata) {
        
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
            labelSection.text = filesText
        } else if filesText == "" {
            labelSection.text = foldersText
        } else {
            labelSection.text = foldersText + ", " + filesText
        }
    }
}
