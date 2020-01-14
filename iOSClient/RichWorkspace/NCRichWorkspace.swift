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

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String) {
        
        var richWorkspaceHtml = ""
        let richWorkspaceArray = richWorkspace.components(separatedBy: "\n")
        for string in richWorkspaceArray {
            if string.hasPrefix("# ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h1><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "# ", with: "") + "</span></h1>"
            } else if string.hasPrefix("## ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h2><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "## ", with: "") + "</span></h2>"
            } else if string.hasPrefix("### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h3><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "### ", with: "") + "</span></h3>"
            } else if string.hasPrefix("#### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h4><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "#### ", with: "") + "</span></h4>"
            } else if string.hasPrefix("##### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h5><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "##### ", with: "") + "</span></h5>"
            } else if string.hasPrefix("###### ") {
                richWorkspaceHtml = richWorkspaceHtml + "<h6><span style=\"color: #000000;\">" + string.replacingOccurrences(of: "###### ", with: "") + "</span></h6>"
            } else {
                richWorkspaceHtml = richWorkspaceHtml + "<span style=\"color: #000000;\">" + string + "</span>"
            }
            richWorkspaceHtml = richWorkspaceHtml + "<br>"
        }
        
        webView.loadHTMLString(richWorkspaceHtml, baseURL: Bundle.main.bundleURL)
        webView.isUserInteractionEnabled = false
    }
}
