//
//  NCViewerRichWorkspace.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 14/01/2020.
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

@objc class NCViewerRichWorkspace: NSObject {

    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var safeAreaBottom: CGFloat = 0
    
    @objc func viewerAt(_ metadata: tableMetadata, detail: CCDetail) {
        
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
