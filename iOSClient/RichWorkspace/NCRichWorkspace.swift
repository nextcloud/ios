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
import SwiftRichString

@objc class NCViewRichWorkspace: UIView {
    
    @IBOutlet weak var textView: UITextView!
    var richWorkspace: String = ""
    var gradient: Bool = false
    let gradientLayer: CAGradientLayer = CAGradientLayer()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        setRichWorkspaceText(richWorkspace, gradient: gradient)
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String, gradient: Bool) {
        
        self.richWorkspace = richWorkspace
        self.gradient = gradient
        
        let h1 = Style {
            $0.font = UIFont.systemFont(ofSize: 25, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h2 = Style {
            $0.font = UIFont.systemFont(ofSize: 23, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h3 = Style {
            $0.font = UIFont.systemFont(ofSize: 21, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h4 = Style {
            $0.font = UIFont.systemFont(ofSize: 19, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h5 = Style {
            $0.font = UIFont.systemFont(ofSize: 17, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h6 = Style {
            $0.font = UIFont.systemFont(ofSize: 15, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let normal = Style {
            $0.font = UIFont.systemFont(ofSize: 15)
            $0.color = NCBrandColor.sharedInstance.textView
        }
       
        var richWorkspaceStyling = ""
        let richWorkspaceArray = richWorkspace.components(separatedBy: "\n")
        for string in richWorkspaceArray {
            if string.hasPrefix("# ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h1>" + string.replacingOccurrences(of: "# ", with: "") + "</h1>\r\n"
            } else if string.hasPrefix("## ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h2>" + string.replacingOccurrences(of: "## ", with: "") + "</h2>\r\n"
            } else if string.hasPrefix("### ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h3>" + string.replacingOccurrences(of: "### ", with: "") + "</h3>\r\n"
            } else if string.hasPrefix("#### ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h4>" + string.replacingOccurrences(of: "#### ", with: "") + "</h4>\r\n"
            } else if string.hasPrefix("##### ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h5>" + string.replacingOccurrences(of: "##### ", with: "") + "</h5>\r\n"
            } else if string.hasPrefix("###### ") {
                richWorkspaceStyling = richWorkspaceStyling + "<h6>" + string.replacingOccurrences(of: "###### ", with: "") + "</h6>\r\n"
            } else {
                richWorkspaceStyling = richWorkspaceStyling + string + "\r\n"
            }
        }
        
        textView.attributedText = richWorkspaceStyling.set(style: StyleGroup(base: normal, ["h1": h1, "h2": h2, "h3": h3, "h4": h4, "h5": h5, "h6": h6]))
        textView.isUserInteractionEnabled = false
        textView.sizeToFit()
        
        if gradient {
            
            gradientLayer.removeFromSuperlayer()
            gradientLayer.frame = CGRect(x: 0.0, y: 0.0, width: self.frame.width, height: self.frame.height)
            if CCUtility.getDarkMode() {
                gradientLayer.colors = [UIColor.init(white: 0, alpha: 0).cgColor, UIColor.black.cgColor]
            } else {
                gradientLayer.colors = [UIColor.init(white: 1, alpha: 0).cgColor, UIColor.white.cgColor]
            }
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.60)
            gradientLayer.endPoint = CGPoint(x: 0, y: 1)
            textView.layer.addSublayer(gradientLayer)
        }
    }
}
