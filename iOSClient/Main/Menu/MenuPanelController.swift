//
//  MenuPanelController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 23.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import FloatingPanel

class MenuPanelController: FloatingPanelController {

    var panelWidth: Int? = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        self.surfaceView.grabberHandle.isHidden = true
        self.isRemovalInteractionEnabled = true
        if #available(iOS 11, *) {
            self.surfaceView.cornerRadius = 16
        } else {
            self.surfaceView.cornerRadius = 0
        }
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        if let width = panelWidth {
            self.view.frame = CGRect(x: 0, y: 0, width: width, height: Int(self.view.frame.height))
        }
    }
    
}
