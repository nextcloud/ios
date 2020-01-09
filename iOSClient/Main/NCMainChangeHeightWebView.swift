//
//  NCMainChangeHeightWebView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/2020.
//  Copyright © 2020 TWS. All rights reserved.
//

import Foundation

class NCMainChangeHeightWebView: UIView {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var startPosition: CGPoint?
    var originalHeight: CGFloat = 0
    let minHeight: CGFloat = 10
    let maxHeight: CGFloat = UIScreen.main.bounds.size.height/3
    
    @IBOutlet weak var imageDrag: UIImageView!

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.backgroundColor = NCBrandColor.sharedInstance.brand
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
    }
    
    @objc func changeTheming() {
        self.backgroundColor = NCBrandColor.sharedInstance.brand
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
        let currentviewSectionWebViewHeight = appDelegate.activeMain.viewSectionWebViewHeight.constant
        let differenceSectionWebViewHeight = currentviewSectionWebViewHeight + difference
        
        if differenceSectionWebViewHeight <= minHeight {
            appDelegate.activeMain.viewSectionWebViewHeight.constant = minHeight
        }
        else if differenceSectionWebViewHeight >= maxHeight {
            appDelegate.activeMain.viewSectionWebViewHeight.constant = maxHeight
        }
        else {
            appDelegate.activeMain.viewSectionWebViewHeight.constant = differenceSectionWebViewHeight
        }
    }

    
}
