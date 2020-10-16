//
//  NCViewer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/10/2020.
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

class NCViewer: NSObject {
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate

    init(viewController: UIViewController, metadata: tableMetadata) {
        super.init()

        if metadata.typeFile == k_metadataTypeFile_document {
                
            // PDF
            if metadata.contentType == "application/pdf" {
                    
                guard let navigationController = viewController.navigationController else { return }
                let viewController:NCViewerPDF = UIStoryboard(name: "NCViewerPDF", bundle: nil).instantiateInitialViewController() as! NCViewerPDF
                
                viewController.metadata = metadata
                viewController.viewer = self
                
                navigationController.pushViewController(viewController, animated: true)
            }
        }
    }
}

/*
 @objc func segueMetadata(_ metadata: tableMetadata) {
     if self.appDelegate.activeViewController is NCFiles {
         (self.appDelegate.activeViewController as! NCFiles).segue(metadata: metadata)
     } else if self.appDelegate.activeViewController is NCFavorite {
         (self.appDelegate.activeViewController as! NCFavorite).segue(metadata: metadata)
     } else if self.appDelegate.activeViewController is NCOffline {
         (self.appDelegate.activeViewController as! NCOffline).segue(metadata: metadata)
     } else if self.appDelegate.activeViewController is NCRecent {
         (self.appDelegate.activeViewController as! NCRecent).segue(metadata: metadata)
     } else if self.appDelegate.activeViewController is NCFileViewInFolder {
         (self.appDelegate.activeViewController as! NCFileViewInFolder).segue(metadata: metadata)
     }
 }
 */
