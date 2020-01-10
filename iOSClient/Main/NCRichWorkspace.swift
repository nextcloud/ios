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
    @IBOutlet weak var viewTouch: NCRichWorkspaceViewTouch!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
        self.backgroundColor = NCBrandColor.sharedInstance.brand;
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.brand;
    }
}

@objc class NCRichWorkspaceViewTouch: UIView {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var startPosition: CGPoint?
    var originalHeight: CGFloat = 0
    let minHeight: CGFloat = 10
    let maxHeight: CGFloat = UIScreen.main.bounds.size.height/3
    
    @IBOutlet weak var imageDrag: UIImageView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
    }
    
    @objc func changeTheming() {
        imageDrag.image = CCGraphics.changeThemingColorImage(UIImage(named: "dragHorizontal"), width: 20, height: 10, color: NCBrandColor.sharedInstance.brandText)
    }
    
    override func  touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        startPosition = touch?.location(in: self)
        originalHeight = self.frame.height
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        let endPosition = touch?.location(in: self)
        let difference = endPosition!.y - startPosition!.y
        
        /*
        let differenceSectionWebViewHeight = appDelegate.activeMain.constraintHeightRichWorkspace.constant + difference
        
        if differenceSectionWebViewHeight <= minHeight {
            appDelegate.activeMain.constraintHeightRichWorkspace.constant = minHeight
        }
        else if differenceSectionWebViewHeight >= maxHeight {
            appDelegate.activeMain.constraintHeightRichWorkspace.constant = maxHeight
        }
        else {
            appDelegate.activeMain.constraintHeightRichWorkspace.constant = differenceSectionWebViewHeight
        }
        
        // save position
        let currentviewSectionWebViewHeight = Int(appDelegate.activeMain.constraintHeightRichWorkspace.constant)
        CCUtility.setRichWorkspaceHeight(currentviewSectionWebViewHeight)
        */
    }

    
}
