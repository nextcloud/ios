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
        self.backgroundColor = NCBrandColor.sharedInstance.brand;
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.brand;
    }
    
    @objc func setRichWorkspaceText(_ richWorkspace: String?) {
        
        let html = "<h2><span style=\"color: #000000;\">" + richWorkspace! + "</span></h2>"
        
        webView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
        webView.isUserInteractionEnabled = false
    }
}

@objc class NCRichWorkspaceViewTouch: UIView {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var startPosition: CGPoint?
    var originalHeight: CGFloat = 0
    let minHeight: CGFloat = 0
    let maxHeight: CGFloat = UIScreen.main.bounds.size.height/3

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.backgroundColor = NCBrandColor.sharedInstance.separator
    }
    
    /*
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        startPosition = touch?.location(in: self)
        originalHeight = self.frame.height
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let endPosition = touch?.location(in: self)
        let difference = endPosition!.y - startPosition!.y
        if let viewRichWorkspace = appDelegate.activeMain.tableView.tableHeaderView {
            let differenceHeight = viewRichWorkspace.frame.height + difference
            if differenceHeight <= minHeight {
                CCUtility.setRichWorkspaceHeight(minHeight)
            } else if differenceHeight >= maxHeight {
                CCUtility.setRichWorkspaceHeight(maxHeight)
            } else {
                CCUtility.setRichWorkspaceHeight(differenceHeight)
            }
            appDelegate.activeMain.setTableViewHeader()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        appDelegate.activeMain.tableView.reloadData()
    }
    */
}
