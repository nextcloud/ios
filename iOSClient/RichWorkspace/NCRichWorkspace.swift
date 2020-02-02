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
    
    @objc @IBOutlet weak var textView: UITextView!
    @objc @IBOutlet weak var textViewTopConstraint: NSLayoutConstraint!

    var markdownParser = MarkdownParser()
    var richWorkspaceText: String?
    //var textViewColor: UIColor?
    //let gradientLayer: CAGradientLayer = CAGradientLayer()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "applicationWillEnterForeground"), object: nil)
        changeTheming()
    }

    @objc func changeTheming() {
        
        markdownParser = MarkdownParser(font: UIFont.systemFont(ofSize: 15), color: NCBrandColor.sharedInstance.textView)
        markdownParser.header.font = UIFont.systemFont(ofSize: 25)
        if let richWorkspaceText = richWorkspaceText {
            textView.attributedText = markdownParser.parse(richWorkspaceText)
        }
    }
    
    @objc func load(richWorkspaceText: String) {
        if richWorkspaceText != self.richWorkspaceText {
            textView.attributedText = markdownParser.parse(richWorkspaceText)
            self.richWorkspaceText = richWorkspaceText
        }
    }
    
    /*
    @objc func setGradient() {
        
        gradientLayer.removeFromSuperlayer()
        gradientLayer.frame = CGRect(x: 0.0, y: 0.0, width: textView.frame.width, height: textView.frame.height)
        if CCUtility.getDarkMode() {
            gradientLayer.colors = [UIColor.init(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
        } else {
            gradientLayer.colors = [UIColor.init(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
        }
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.60)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        textView.layer.addSublayer(gradientLayer)
    }
    */
}
