//
//  NCViewerRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/01/2020.
//  Copyright © 2020 TWS. All rights reserved.
//

import Foundation

@objc class NCViewerRichWorkspace: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: CGFloat = 0
    
    @objc static let shared: NCViewerRichWorkspace = {
        let instance = NCViewerRichWorkspace()
        return instance
    }()
    
    @objc func viewerRichWorkspaceAt(_ metadata: tableMetadata, detail: CCDetail) {
        
        if #available(iOS 11.0, *) {
            safeAreaBottom = (UIApplication.shared.keyWindow?.safeAreaInsets.bottom)!
        }
        
        let width: CGFloat = detail.view.frame.size.width
        let height: CGFloat = detail.view.frame.size.height - safeAreaBottom - CGFloat(k_detail_Toolbar_Height)
        
        let viewRichWorkspace = Bundle.main.loadNibNamed("NCRichWorkspace", owner: self, options: nil)?.first as! NCViewRichWorkspace
        viewRichWorkspace.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        viewRichWorkspace.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: width, height: height)
        
        if let directory = NCManageDatabase.sharedInstance.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", metadata.account, metadata.serverUrl)) {
            viewRichWorkspace.setRichWorkspaceText(directory.richWorkspace)
        }
        
        detail.view.addSubview(viewRichWorkspace)
    }
}
