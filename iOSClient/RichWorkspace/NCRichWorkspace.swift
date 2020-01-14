//
//  NCRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/2020.
//  Copyright © 2020 TWS. All rights reserved.
//

import Foundation

@objc class NCViewRichWorkspace: UIView {
    
    @IBOutlet weak var webView: WKWebView!
    var richWorkspace: String = ""

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
        setRichWorkspaceText(richWorkspace)
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String) {
        
        var color =  "#000000"
        if CCUtility.getDarkMode() {
            color =  "#FFFFFF"
        }
    
        self.richWorkspace = richWorkspace
        var richWorkspaceHtml = ""
        let richWorkspaceArray = richWorkspace.components(separatedBy: "\n")
        
        for string in richWorkspaceArray {
            if string.hasPrefix("# ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h1><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "# ", with: "") + "</span></h1>"
            } else if string.hasPrefix("## ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h2><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "## ", with: "") + "</span></h2>"
            } else if string.hasPrefix("### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h3><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "### ", with: "") + "</span></h3>"
            } else if string.hasPrefix("#### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h4><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "#### ", with: "") + "</span></h4>"
            } else if string.hasPrefix("##### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h5><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "##### ", with: "") + "</span></h5>"
            } else if string.hasPrefix("###### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h6><span style=\"color: \(color);\">" + string.replacingOccurrences(of: "###### ", with: "") + "</span></h6>"
            } else {
                richWorkspaceHtml = richWorkspaceHtml + "<span style=\"color: \(color);\">" + string + "</span>"
            }
            richWorkspaceHtml = richWorkspaceHtml + "<br>"
        }
        
        richWorkspaceHtml = "<!DOCTYPE html><html><body>" + richWorkspaceHtml + "</body></html>"
        
        webView.loadHTMLString(richWorkspaceHtml, baseURL: Bundle.main.bundleURL)
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
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
