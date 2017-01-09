//
//  CCCreateCloud.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 09/01/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import Foundation

class CreateMenu: NSObject {
    
    func createMenuPlain(view : UIView) {
        
        let actionSheet = AHKActionSheet.init(view: view, title: nil)
        
        actionSheet?.addButton(withTitle: "Crea cartella", image: UIImage(named: "folder"), type: AHKActionSheetButtonType.default, handler: {(AHKActionSheet) -> Void in
            NSLog("Share tapped")
        })
        
        
        actionSheet?.show()
    }
}
