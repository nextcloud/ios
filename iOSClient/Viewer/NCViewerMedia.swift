//
//  NCViewerMedia.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/09/18.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation
import KTVHTTPCache

class NCViewerMedia: NSObject {
    
    @objc static let sharedInstance: NCViewerMedia = {
        let instance = NCViewerMedia()
        return instance
    }()

    var viewDetail: CCDetail!
    var metadata: tableMetadata!
    var videoURL: URL!
    var videoURLProxy: URL!
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @objc func viewMedia(_ metadata: tableMetadata, viewDetail: CCDetail, width: Int, height: Int) {
        
        self.viewDetail = viewDetail
        self.metadata = metadata
        
        guard let serverUrl = NCManageDatabase.sharedInstance.getServerUrl(metadata.directoryID) else {
            return
        }
        
        if CCUtility.fileProviderStorageExists(metadata.fileID, fileNameView: metadata.fileNameView) {
            self.videoURL = URL(string: CCUtility.getDirectoryProviderStorageFileID(metadata.fileID, fileNameView: metadata.fileNameView))
            self.videoURLProxy = videoURL
        } else {
            guard let stringURL = (serverUrl + "/" + metadata.fileName).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                return
            }
            self.videoURL = URL(string: stringURL)
            self.videoURLProxy = KTVHTTPCache.proxyURL(withOriginalURL: self.videoURL)
            
            guard let authData = (appDelegate.activeUser + ":" + appDelegate.activePassword).data(using: .utf8) else {
                return
            }
            let authValue = "Basic " + authData.base64EncodedString(options: [])
            let header = [authValue:"Authorization", CCUtility.getUserAgent():"User-Agent"] as [String : String]
            KTVHTTPCache.downloadSetAdditionalHeaders(header)
        }
        
        appDelegate.player = AVPlayer(url: videoURLProxy)
        appDelegate.playerController = AVPlayerViewController()
        
        appDelegate.playerController.player = appDelegate.player
        appDelegate.playerController.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        appDelegate.playerController.allowsPictureInPicturePlayback = false
        viewDetail.addChild(appDelegate.playerController)
        viewDetail.view.addSubview(appDelegate.playerController.view)
        appDelegate.playerController.didMove(toParent: viewDetail)
    }
    
}
