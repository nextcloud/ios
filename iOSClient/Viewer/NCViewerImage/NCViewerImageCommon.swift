//
//  NCViewerImageCommon.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 04/03/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

class NCViewerImageCommon: NSObject {
    @objc static let shared: NCViewerImageCommon = {
        let instance = NCViewerImageCommon()
        return instance
    }()
    
    func getThumbnailImage(metadata: tableMetadata) -> UIImage? {
        
        if CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            let imagePath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            return UIImage.init(contentsOfFile: imagePath)
        }
        
        return nil
    }
    
    func imageChangeSizeView(mediaBrowser: MediaBrowserViewController?, size: CGSize, metadata: tableMetadata?) {
        guard let mediaBrowser = mediaBrowser else { return }
        
        var image: UIImage?
        var contentViewSaved : MediaContentView?
        for contentView in mediaBrowser.contentViews {
            if contentView.position == 0 && contentView.isLoading == false {
                image = contentView.image
                contentViewSaved = contentView
                if metadata != nil , let thumbnailImage = self.getThumbnailImage(metadata: metadata!) {
                    contentView.image = thumbnailImage
                } else {
                    contentView.image = nil
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            mediaBrowser.changeInViewSize(to: size)
            if image != nil {
                contentViewSaved?.image = image
            }
        }
    }

}
