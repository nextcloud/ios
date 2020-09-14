//
//  NCViewRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

@objc class NCViewRichWorkspace: UIView {
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var richView: UIView!
    @IBOutlet weak var sortButton: UIButton!
    @objc @IBOutlet weak var textView: UITextView!
    
    private var markdownParser = MarkdownParser()
    private var richWorkspaceText: String?
    private var textViewColor: UIColor?
    private let gradient : CAGradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        NotificationCenter.default.addObserver(self, selector: #selector(changeTheming), name: NSNotification.Name(rawValue: k_notificationCenter_changeTheming), object: nil)
        changeTheming()
        
        // Gradient
        gradient.startPoint = CGPoint(x: 0, y: 0.60)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        richView.layer.addSublayer(gradient)
    }
    
    override func layoutSublayers(of layer: CALayer) {
        super.layoutSublayers(of: layer)
        gradient.frame = self.richView.bounds
    }

    @objc func changeTheming() {
        if textViewColor != NCBrandColor.sharedInstance.textView {
            markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.sharedInstance.textView)
            markdownParser.header.font = UIFont.systemFont(ofSize: 25)
            if let richWorkspaceText = richWorkspaceText {
                textView.attributedText = markdownParser.parse(richWorkspaceText)
            }
            textViewColor = NCBrandColor.sharedInstance.textView
            
            if CCUtility.getDarkMode() {
                gradient.colors = [UIColor.init(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
            } else {
                gradient.colors = [UIColor.init(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
            }
        }
    }
    
    @objc func load(richWorkspaceText: String) {
        if richWorkspaceText != self.richWorkspaceText {
            textView.attributedText = markdownParser.parse(richWorkspaceText)
            self.richWorkspaceText = richWorkspaceText
        }
    }
}
