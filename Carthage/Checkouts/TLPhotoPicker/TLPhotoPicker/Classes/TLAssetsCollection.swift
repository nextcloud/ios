//
//  TLAssetsCollection.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 18..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import Foundation
import Photos
import PhotosUI
import MobileCoreServices

public struct TLPHAsset {
    enum CloudDownloadState {
        case ready, progress, complete, failed
    }
    
    public enum AssetType {
        case photo, video, livePhoto
    }
    
    public enum ImageExtType: String {
        case png, jpg, gif, heic
    }
    
    var state = CloudDownloadState.ready
    public var phAsset: PHAsset? = nil
    //Bool to check if TLPHAsset returned is created using camera.
    public var isSelectedFromCamera = false
    public var selectedOrder: Int = 0
    public var type: AssetType {
        get {
            guard let phAsset = self.phAsset else { return .photo }
            if phAsset.mediaSubtypes.contains(.photoLive) {
                return .livePhoto
            }else if phAsset.mediaType == .video {
                return .video
            }else {
                return .photo
            }
        }
    }
    
    public var fullResolutionImage: UIImage? {
        get {
            guard let phAsset = self.phAsset else { return nil }
            return TLPhotoLibrary.fullResolutionImageData(asset: phAsset)
        }
    }
    
    public func extType() -> ImageExtType {
        var ext = ImageExtType.png
        if let fileName = self.originalFileName, let extention = URL(string: fileName)?.pathExtension.lowercased() {
            ext = ImageExtType(rawValue: extention) ?? .png
        }
        return ext
    }
    
    @discardableResult
    public func cloudImageDownload(progressBlock: @escaping (Double) -> Void, completionBlock:@escaping (UIImage?)-> Void ) -> PHImageRequestID? {
        guard let phAsset = self.phAsset else { return nil }
        return TLPhotoLibrary.cloudImageDownload(asset: phAsset, progressBlock: progressBlock, completionBlock: completionBlock)
    }
    
    public var originalFileName: String? {
        get {
            guard let phAsset = self.phAsset,let resource = PHAssetResource.assetResources(for: phAsset).first else { return nil }
            return resource.originalFilename
        }
    }
    
    public func photoSize(options: PHImageRequestOptions? = nil ,completion: @escaping ((Int)->Void), livePhotoVideoSize: Bool = false) {
        guard let phAsset = self.phAsset, self.type == .photo else { completion(-1); return }
        var resource: PHAssetResource? = nil
        if phAsset.mediaSubtypes.contains(.photoLive) == true, livePhotoVideoSize {
            resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .pairedVideo }.first
        }else {
            resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .photo }.first
        }
        if let fileSize = resource?.value(forKey: "fileSize") as? Int {
            completion(fileSize)
        }else {
            PHImageManager.default().requestImageData(for: phAsset, options: nil) { (data, uti, orientation, info) in
                var fileSize = -1
                if let data = data {
                    let bcf = ByteCountFormatter()
                    bcf.countStyle = .file
                    fileSize = data.count
                }
                DispatchQueue.main.async {
                    completion(fileSize)
                }
            }
        }
    }
    
    public func videoSize(options: PHVideoRequestOptions? = nil, completion: @escaping ((Int)->Void)) {
        guard let phAsset = self.phAsset, self.type == .video else {  completion(-1); return }
        let resource = PHAssetResource.assetResources(for: phAsset).filter { $0.type == .video }.first
        if let fileSize = resource?.value(forKey: "fileSize") as? Int {
            completion(fileSize)
        }else {
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avasset, audioMix, info) in
                func fileSize(_ url: URL?) -> Int? {
                    do {
                        guard let fileSize = try url?.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
                        return fileSize
                    }catch { return nil }
                }
                var url: URL? = nil
                if let urlAsset = avasset as? AVURLAsset {
                    url = urlAsset.url
                }else if let sandboxKeys = info?["PHImageFileSandboxExtensionTokenKey"] as? String, let path = sandboxKeys.components(separatedBy: ";").last {
                    url = URL(fileURLWithPath: path)
                }
                let size = fileSize(url) ?? -1
                DispatchQueue.main.async {
                    completion(size)
                }
            }
        }
    }
    
    func MIMEType(_ url: URL?) -> String? {
        guard let ext = url?.pathExtension else { return nil }
        if !ext.isEmpty {
            let UTIRef = UTTypeCreatePreferredIdentifierForTag("public.filename-extension" as CFString, ext as CFString, nil)
            let UTI = UTIRef?.takeUnretainedValue()
            UTIRef?.release()
            if let UTI = UTI {
                guard let MIMETypeRef = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType) else { return nil }
                let MIMEType = MIMETypeRef.takeUnretainedValue()
                MIMETypeRef.release()
                return MIMEType as String
            }
        }
        return nil
    }
    
    @discardableResult
    //convertLivePhotosToJPG
    // false : If you want mov file at live photos
    // true  : If you want png file at live photos ( HEIC )
    public func tempCopyMediaFile(videoRequestOptions: PHVideoRequestOptions? = nil, imageRequestOptions: PHImageRequestOptions? = nil, exportPreset: String = AVAssetExportPresetHighestQuality, convertLivePhotosToJPG: Bool = false, progressBlock:((Double) -> Void)? = nil, completionBlock:@escaping ((URL,String) -> Void)) -> PHImageRequestID? {
        guard let phAsset = self.phAsset else { return nil }
        var type: PHAssetResourceType? = nil
        if phAsset.mediaSubtypes.contains(.photoLive) == true, convertLivePhotosToJPG == false {
            type = .pairedVideo
        }else {
            type = phAsset.mediaType == .video ? .video : .photo
        }
        guard let resource = (PHAssetResource.assetResources(for: phAsset).filter{ $0.type == type }).first else { return nil }
        let fileName = resource.originalFilename
        var writeURL: URL? = nil
        if #available(iOS 10.0, *) {
            writeURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName)")
        } else {
            writeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("\(fileName)")
        }
        if (writeURL?.pathExtension.uppercased() == "HEIC" || writeURL?.pathExtension.uppercased() == "HEIF") && convertLivePhotosToJPG {
            if let fileName2 = writeURL?.deletingPathExtension().lastPathComponent {
                writeURL?.deleteLastPathComponent()
                writeURL?.appendPathComponent("\(fileName2).jpg")
            }
        }
        guard let localURL = writeURL,let mimetype = MIMEType(writeURL) else { return nil }
        switch phAsset.mediaType {
        case .video:
            var requestOptions = PHVideoRequestOptions()
            if let options = videoRequestOptions {
                requestOptions = options
            }else {
                requestOptions.isNetworkAccessAllowed = true
            }
            //iCloud download progress
            requestOptions.progressHandler = { (progress, error, stop, info) in
                DispatchQueue.main.async {
                    progressBlock?(progress)
                }
            }
            return PHImageManager.default().requestExportSession(forVideo: phAsset, options: requestOptions, exportPreset: exportPreset) { (session, infoDict) in
                session?.outputURL = localURL
                session?.outputFileType = AVFileType.mov
                session?.exportAsynchronously(completionHandler: {
                    DispatchQueue.main.async {
                        completionBlock(localURL, mimetype)
                    }
                })
            }
        case .image:
            var requestOptions = PHImageRequestOptions()
            if let options = imageRequestOptions {
                requestOptions = options
            }else {
                requestOptions.isNetworkAccessAllowed = true
            }
            //iCloud download progress
            requestOptions.progressHandler = { (progress, error, stop, info) in
                DispatchQueue.main.async {
                    progressBlock?(progress)
                }
            }
            return PHImageManager.default().requestImageData(for: phAsset, options: requestOptions, resultHandler: { (data, uti, orientation, info) in
                do {
                    var data = data
                    let needConvertLivePhotoToJPG = phAsset.mediaSubtypes.contains(.photoLive) == true && convertLivePhotosToJPG == true
                    if needConvertLivePhotoToJPG, let imgData = data, let rawImage = UIImage(data: imgData)?.upOrientationImage() {
                        data = rawImage.jpegData(compressionQuality: 1)
                    }
                    try data?.write(to: localURL)
                    DispatchQueue.main.async {
                        completionBlock(localURL, mimetype)
                    }
                }catch { }
            })
        default:
            return nil
        }
    }
    
    //Apparently, this method is not be safety to export a video.
    //There is many way that export a video.
    //This method was one of them.
    public func exportVideoFile(options: PHVideoRequestOptions? = nil, progressBlock:((Float) -> Void)? = nil, completionBlock:@escaping ((URL,String) -> Void)) {
        guard let phAsset = self.phAsset, phAsset.mediaType == .video else { return }
        var type = PHAssetResourceType.video
        guard let resource = (PHAssetResource.assetResources(for: phAsset).filter{ $0.type == type }).first else { return }
        let fileName = resource.originalFilename
        var writeURL: URL? = nil
        if #available(iOS 10.0, *) {
            writeURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName)")
        } else {
            writeURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("\(fileName)")
        }
        guard let localURL = writeURL,let mimetype = MIMEType(writeURL) else { return }
        var requestOptions = PHVideoRequestOptions()
        if let options = options {
            requestOptions = options
        }else {
            requestOptions.isNetworkAccessAllowed = true
        }
        //iCloud download progress
        //options.progressHandler = { (progress, error, stop, info) in
            
        //}
        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avasset, avaudioMix, infoDict) in
            guard let avasset = avasset else { return }
            let exportSession = AVAssetExportSession.init(asset: avasset, presetName: AVAssetExportPresetHighestQuality)
            exportSession?.outputURL = localURL
            exportSession?.outputFileType = AVFileType.mov
            exportSession?.exportAsynchronously(completionHandler: {
                completionBlock(localURL,mimetype)
            })
            func checkExportSession() {
                DispatchQueue.global().async { [weak exportSession] in
                    guard let exportSession = exportSession else { return }
                    switch exportSession.status {
                    case .waiting,.exporting:
                        DispatchQueue.main.async {
                            progressBlock?(exportSession.progress)
                        }
                        Thread.sleep(forTimeInterval: 1)
                        checkExportSession()
                    default:
                        break
                    }
                }
            }
            checkExportSession()
        }
    }
    
    init(asset: PHAsset?) {
        self.phAsset = asset
    }

    public static func asset(with localIdentifier: String) -> TLPHAsset? {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        return TLPHAsset(asset: fetchResult.firstObject)
    }
}

extension TLPHAsset: Equatable {
    public static func ==(lhs: TLPHAsset, rhs: TLPHAsset) -> Bool {
        guard let lphAsset = lhs.phAsset, let rphAsset = rhs.phAsset else { return false }
        return lphAsset.localIdentifier == rphAsset.localIdentifier
    }
}

extension Array {
    subscript (safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}

public struct TLAssetsCollection {
    var phAssetCollection: PHAssetCollection? = nil
    var fetchResult: PHFetchResult<PHAsset>? = nil
    var useCameraButton: Bool = false
    var recentPosition: CGPoint = CGPoint.zero
    var title: String
    var localIdentifier: String
    public var sections: [(title: String, assets: [TLPHAsset])]? = nil
    var count: Int {
        get {
            guard let count = self.fetchResult?.count, count > 0 else { return self.useCameraButton ? 1 : 0 }
            return count + (self.useCameraButton ? 1 : 0)
        }
    }
    
    init(collection: PHAssetCollection) {
        self.phAssetCollection = collection
        self.title = collection.localizedTitle ?? ""
        self.localIdentifier = collection.localIdentifier
    }
    
    func getAsset(at index: Int) -> PHAsset? {
        if self.useCameraButton && index == 0 { return nil }
        let index = index - (self.useCameraButton ? 1 : 0)
        guard let result = self.fetchResult, index < result.count else { return nil }
        return result.object(at: max(index,0))
    }
    
    func getTLAsset(at indexPath: IndexPath) -> TLPHAsset? {
        let isCameraRow = self.useCameraButton && indexPath.section == 0 && indexPath.row == 0
        if isCameraRow {
            return nil
        }
        if let sections = self.sections {
            let index = indexPath.row - ((self.useCameraButton && indexPath.section == 0) ? 1 : 0)
            let result = sections[safe: indexPath.section]
            return result?.assets[safe: index]
        }else {
            var index = indexPath.row
            index = index - (self.useCameraButton ? 1 : 0)
            guard let result = self.fetchResult, index < result.count else { return nil }
            return TLPHAsset(asset: result.object(at: max(index,0)))
        }
    }
    
    mutating func reloadSection(groupedBy: PHFetchedResultGroupedBy) {
        var groupedSections = self.section(groupedBy: groupedBy)
        if self.useCameraButton {
            groupedSections.insert(("camera",[TLPHAsset(asset: nil)]), at: 0)
        }
        self.sections = groupedSections
    }
    
    static func ==(lhs: TLAssetsCollection, rhs: TLAssetsCollection) -> Bool {
        return lhs.localIdentifier == rhs.localIdentifier
    }
}

extension UIImage {
    func upOrientationImage() -> UIImage? {
        switch imageOrientation {
        case .up:
            return self
        default:
            UIGraphicsBeginImageContextWithOptions(size, false, scale)
            draw(in: CGRect(origin: .zero, size: size))
            let result = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return result
        }
    }
}
