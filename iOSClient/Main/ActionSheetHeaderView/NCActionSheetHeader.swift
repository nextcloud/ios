//
//  NCActionSheetHeader.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 08/11/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
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

class NCActionSheetHeader: NSObject {
    
    @objc static let sharedInstance: NCActionSheetHeader = {
        let instance = NCActionSheetHeader()
        return instance
    }()
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    func actionSheetHeader(isDirectory: Bool, iconName: String, ocId: String, etag: String, text: String) -> UIView? {
        
        var image: UIImage?
        
        // Header
        if isDirectory {
            image = CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement)
        } else if iconName.count > 0 {
            image = UIImage.init(named: iconName)
        } else {
            image = UIImage.init(named: "file")
        }
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag)) {
            image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(ocId, etag: etag))
        }
        
        let headerView = UINib(nibName: "NCActionSheetHeaderView", bundle: nil).instantiate(withOwner: self, options: nil).first as! NCActionSheetHeaderView
        
        headerView.backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        headerView.imageItem.image = image
        headerView.label.text = text
        headerView.label.textColor = NCBrandColor.sharedInstance.icon
        
        return headerView
    }
}
