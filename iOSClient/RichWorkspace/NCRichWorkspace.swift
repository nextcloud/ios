//
//  NCRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/2020.
//  Copyright © 2020 TWS. All rights reserved.
//

import Foundation
import SwiftRichString

@objc class NCViewRichWorkspace: UIView {
    
    @IBOutlet weak var textLabel: UILabel!
    var richWorkspace: String = ""

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        setRichWorkspaceText(richWorkspace)
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String) {
        
        let h1 = Style {
            $0.font = UIFont.systemFont(ofSize: 20, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h2 = Style {
            $0.font = UIFont.systemFont(ofSize: 18, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h3 = Style {
            $0.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h4 = Style {
            $0.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h5 = Style {
            $0.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let h6 = Style {
            $0.font = UIFont.systemFont(ofSize: 10, weight: .bold)
            $0.color = NCBrandColor.sharedInstance.textView
        }
        let normal = Style {
            $0.font = UIFont.systemFont(ofSize: 10)
            $0.color = NCBrandColor.sharedInstance.textView
        }
       
        self.richWorkspace = richWorkspace
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
        
        textLabel.attributedText = richWorkspaceStyling.set(style: StyleGroup(base: normal, ["h1": h1, "h2": h2, "h3": h3, "h4": h4, "h5": h5, "h6": h6]))
        textLabel.isUserInteractionEnabled = false
    }
}

extension UIColor {
    public convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xff000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00ff0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000ff00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000ff) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}
