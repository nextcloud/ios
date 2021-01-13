//
//  NCViewerPeekPop.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 12/01/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import NCCommunication

class NCViewerPeekPop: UIViewController  {

    private let imageView = UIImageView()

    override func loadView() {
        view = imageView
    }
    
    init(metadata: tableMetadata) {
        
        super.init(nibName: nil, bundle: nil)

        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        
        if metadata.directory {

            imageView.image = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: UIScreen.main.bounds.width / 2)
            preferredContentSize = CGSize(width: imageView.image?.size.width ?? 0,  height: imageView.image?.size.height ?? 0)

        } else {
            
            imageView.image = UIImage.init(named: metadata.iconName)
            preferredContentSize = CGSize(width: imageView.image?.size.width ?? 0,  height: imageView.image?.size.height ?? 0)
        
            if metadata.hasPreview {
                
                if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                    
                    if let fullImage = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)) {
                        imageView.image = fullImage.resizeImage(size: CGSize(width: view.bounds.size.width, height: view.bounds.size.height), isAspectRation: true)
                        preferredContentSize = CGSize(width: imageView.image?.size.width ?? 0,  height: imageView.image?.size.height ?? 0)
                    }
                    
                } else {
                    
                    let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, account: metadata.account)!
                    let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                    let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
                    
                    NCCommunication.shared.downloadPreview(fileNamePathOrFileId: fileNamePath, fileNamePreviewLocalPath: fileNamePreviewLocalPath, widthPreview: NCBrandGlobal.shared.sizePreview, heightPreview: NCBrandGlobal.shared.sizePreview, fileNameIconLocalPath: fileNameIconLocalPath, sizeIcon: NCBrandGlobal.shared.sizeIcon) { (account, imagePreview, imageIcon,  errorCode, errorMessage) in
                        if errorCode == 0 && imagePreview != nil {
                            self.imageView.image = imagePreview!.resizeImage(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height), isAspectRation: true)
                            self.preferredContentSize = CGSize(width: self.imageView.image?.size.width ?? 0,  height: self.imageView.image?.size.height ?? 0)
                        }
                    }
                }
            }
        }
        
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
