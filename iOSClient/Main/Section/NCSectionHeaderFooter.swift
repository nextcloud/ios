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
import MarkdownKit

class NCSectionHeaderMenu: UICollectionReusableView, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var buttonMore: UIButton!
    @IBOutlet weak var buttonSwitch: UIButton!
    @IBOutlet weak var buttonOrder: UIButton!
    @IBOutlet weak var buttonOrderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var viewRichWorkspace: UIView!
    @IBOutlet weak var viewRichWorkspaceHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var textViewRichWorkspace: UITextView!
    @IBOutlet weak var separator: UIView!
    
    var delegate: NCSectionHeaderMenuDelegate?
    
    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private var textViewColor: UIColor?
    private let gradient : CAGradientLayer = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        buttonSwitch.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "switchList"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        buttonOrder.setTitle("", for: .normal)
        buttonOrder.setTitleColor(NCBrandColor.sharedInstance.brandElement, for: .normal)
        
        buttonMore.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.icon), for: .normal)
        
        separator.backgroundColor = NCBrandColor.sharedInstance.separator
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        
        // Gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.60)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        viewRichWorkspace.layer.addSublayer(gradient)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(touchUpInsideViewRichWorkspace(_:)))
        tap.delegate = self
        viewRichWorkspace?.addGestureRecognizer(tap)
        
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = viewRichWorkspace.bounds
    }
    
    @objc func changeTheming() {
        if textViewColor != NCBrandColor.sharedInstance.textView {
            markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.sharedInstance.textView)
            markdownParser.header.font = UIFont.systemFont(ofSize: 25)
            if let richWorkspaceText = richWorkspaceText {
                textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
            }
            textViewColor = NCBrandColor.sharedInstance.textView
            
            if CCUtility.getDarkMode() {
                gradient.colors = [UIColor.init(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
            } else {
                gradient.colors = [UIColor.init(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
            }
        }
    }
    
    func setTitleSorted(datasourceTitleButton: String) {
        
        let title = NSLocalizedString(datasourceTitleButton, comment: "")
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
    
    func setRichWorkspaceText(richWorkspaceText: String?) {
        guard let richWorkspaceText = richWorkspaceText else { return }
        if richWorkspaceText != self.richWorkspaceText {
            textViewRichWorkspace.attributedText = markdownParser.parse(richWorkspaceText)
            self.richWorkspaceText = richWorkspaceText
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
    
    @objc func touchUpInsideViewRichWorkspace(_ sender: Any) {
        delegate?.tapRichWorkspace(sender: sender)
    }
}

protocol NCSectionHeaderMenuDelegate {
    func tapSwitchHeader(sender: Any)
    func tapMoreHeader(sender: Any)
    func tapOrderHeader(sender: Any)
    func tapRichWorkspace(sender: Any)
}

class NCSectionFooter: UICollectionReusableView {
    
    @IBOutlet weak var labelSection: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.backgroundColor = UIColor.clear
        labelSection.textColor = NCBrandColor.sharedInstance.icon
    }
    
    func setTitleLabel(directories: Int, files: Int, size: Double) {
        
        var foldersText = ""
        var filesText = ""
        
        if directories > 1 {
            foldersText = "\(directories) " + NSLocalizedString("_folders_", comment: "")
        } else if directories == 1 {
            foldersText = "1 " + NSLocalizedString("_folder_", comment: "")
        }
        
        if files > 1 {
            filesText = "\(files) " + NSLocalizedString("_files_", comment: "") + " " + CCUtility.transformedSize(size)
        } else if files == 1 {
            filesText = "1 " + NSLocalizedString("_file_", comment: "") + " " + CCUtility.transformedSize(size)
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
