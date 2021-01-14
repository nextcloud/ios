//
//  NCViewerProviderContextMenu.swift
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

class NCViewerProviderContextMenu: UIViewController  {

    private let imageView = UIImageView()
    private let standardSizeWidth = UIScreen.main.bounds.width / 2
    private let standardSizeHeight = UIScreen.main.bounds.height / 2

    override func loadView() {
        view = imageView
    }
    
    init(metadata: tableMetadata) {
        super.init(nibName: nil, bundle: nil)

        let ext = CCUtility.getExtension(metadata.fileNameView)
        let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        let imagePathPreview = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!

        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
                
        if metadata.directory {

            imageView.image = UIImage(named: "folder")!.image(color: NCBrandColor.shared.brandElement, size: standardSizeWidth)

        } else {
            
            imageView.image = UIImage.init(named: metadata.iconName)?.resizeImage(size: CGSize(width: standardSizeWidth, height: standardSizeHeight), isAspectRation: true)
        
            if metadata.hasPreview {
                       
                if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) {
                    if ext == "GIF" {
                        imageView.image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath))
                    } else {
                        imageView.image = UIImage.init(contentsOfFile: imagePath)
                    }
                } else if CCUtility.fileProviderStoragePreviewIconExists(metadata.ocId, etag: metadata.etag) {
                    imageView.image = UIImage.init(contentsOfFile: imagePathPreview)
                }
            }
        }
        
        if let size = imageView.image?.size {
            preferredContentSize = size
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}
