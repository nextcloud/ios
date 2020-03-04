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
    
    func getMetadatasDatasource(metadata: tableMetadata?, favoriteDatasorce: Bool, mediaDatasorce: Bool, offLineDatasource: Bool) -> [tableMetadata]? {
        guard let metadata = metadata else { return nil }
        if favoriteDatasorce {
            return NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND favorite == 1 AND typeFile == %@", metadata.account, k_metadataTypeFile_image), sorted: CCUtility.getOrderSettings(), ascending: CCUtility.getAscendingSettings())
        } else if mediaDatasorce {
            return NCManageDatabase.sharedInstance.getMedias(account: metadata.account, predicate: NSPredicate(format: "account == %@ AND typeFile == %@", metadata.account, k_metadataTypeFile_image))
        } else if offLineDatasource {
            var datasourceSorted = ""
            var datasourceAscending = true
            (_, datasourceSorted, datasourceAscending, _, _) = NCUtility.sharedInstance.getLayoutForView(key: k_layout_view_offline)
            if let files = NCManageDatabase.sharedInstance.getTableLocalFiles(predicate: NSPredicate(format: "account == %@ AND offline == true", metadata.account), sorted: datasourceSorted, ascending: datasourceAscending) {
                var ocIds = [String]()
                for file: tableLocalFile in files {
                    ocIds.append(file.ocId)
                }
                return NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND ocId IN %@", metadata.account, ocIds), sorted: datasourceSorted, ascending: datasourceAscending)
            }
        } else {
            return NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND typeFile == %@", metadata.account, metadata.serverUrl, k_metadataTypeFile_image), sorted: CCUtility.getOrderSettings(), ascending: CCUtility.getAscendingSettings())
        }
        
        return nil
    }
    
    func getThumbnailImage(metadata: tableMetadata) -> UIImage? {
        
        if CCUtility.fileProviderStorageIconExists(metadata.ocId, fileNameView: metadata.fileNameView) {
            let imagePath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            return UIImage.init(contentsOfFile: imagePath)
        }
        
        return nil
    }
    
    func getImage(metadata: tableMetadata) -> UIImage? {
        
        var image: UIImage?
        
        if CCUtility.fileProviderStorageSize(metadata.ocId, fileNameView: metadata.fileNameView) > 0 {
           
            let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
            let ext = CCUtility.getExtension(metadata.fileNameView)
            if ext == "GIF" { image = UIImage.animatedImage(withAnimatedGIFURL: URL(fileURLWithPath: imagePath)) }
            else { image = UIImage.init(contentsOfFile: imagePath) }
        }
        
        return image
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
        DispatchQueue.main.async {
        //DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            mediaBrowser.changeInViewSize(to: size)
            if image != nil {
                contentViewSaved?.image = image
            }
        }
    }

}
