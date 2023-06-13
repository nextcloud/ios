//
//  NCCameraRoll.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 21/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
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
import NextcloudKit
import JGProgressHUD

class NCCameraRoll: NSObject {

    func extractCameraRoll(from metadata: tableMetadata, viewController: UIViewController?, hud: JGProgressHUD, completition: @escaping (_ metadatas: [tableMetadata]) -> Void) {

        let chunckSize = CCUtility.getChunkSize() * 1000000
        var metadatas: [tableMetadata] = []
        let metadataSource = tableMetadata.init(value: metadata)

        guard !metadata.isExtractFile else { return  completition([metadataSource]) }
        guard !metadataSource.assetLocalIdentifier.isEmpty else {
            let filePath = CCUtility.getDirectoryProviderStorageOcId(metadataSource.ocId, fileNameView: metadataSource.fileName)!
            metadataSource.size = NCUtilityFileSystem.shared.getFileSize(filePath: filePath)
            let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadataSource.fileNameView, mimeType: metadataSource.contentType, directory: false)
            metadataSource.contentType = results.mimeType
            metadataSource.iconName = results.iconName
            metadataSource.classFile = results.classFile
            if let date = NCUtilityFileSystem.shared.getFileCreationDate(filePath: filePath) {
                metadataSource.creationDate = date
            }
            if let date = NCUtilityFileSystem.shared.getFileModificationDate(filePath: filePath) {
                metadataSource.date = date
            }
            metadataSource.chunk = chunckSize != 0 && metadata.size > chunckSize
            metadataSource.isExtractFile = true
            if let metadata = NCManageDatabase.shared.addMetadata(metadataSource) {
                metadatas.append(metadata)
            }
            return completition(metadatas)
        }

        extractImageVideoFromAssetLocalIdentifier(metadata: metadataSource, modifyMetadataForUpload: true, viewController: viewController, hud: hud) { metadata, fileNamePath, error in
            if let metadata = metadata, let fileNamePath = fileNamePath, !error {
                metadatas.append(metadata)
                let toPath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
                NCUtilityFileSystem.shared.moveFile(atPath: fileNamePath, toPath: toPath)
                let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadataSource.assetLocalIdentifier], options: nil)
                if metadata.livePhoto, fetchAssets.count > 0 {
                    self.createMetadataLivePhoto(metadata: metadata, asset: fetchAssets.firstObject) { metadata in
                        if let metadata = metadata, let metadata = NCManageDatabase.shared.addMetadata(metadata) {
                            metadatas.append(metadata)
                        }
                        completition(metadatas)
                    }
                } else {
                    completition(metadatas)
                }
            } else {
                completition(metadatas)
            }
        }
    }

    func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata,
                                                   modifyMetadataForUpload: Bool,
                                                   viewController: UIViewController?,
                                                   hud: JGProgressHUD,
                                                   completion: @escaping (_ metadata: tableMetadata?, _ fileNamePath: String?, _ error: Bool) -> Void) {

        var fileNamePath: String?
        let metadata = tableMetadata.init(value: metadata)
        let chunckSize = CCUtility.getChunkSize() * 1000000
        var compatibilityFormat: Bool = false

        func callCompletionWithError(_ error: Bool = true) {
            if error {
                completion(nil, nil, true)
            } else {
                var metadataReturn = metadata
                if modifyMetadataForUpload {
                    metadata.chunk = chunckSize != 0 && metadata.size > chunckSize
                    metadata.isExtractFile = true
                    if let metadata = NCManageDatabase.shared.addMetadata(metadata) {
                        metadataReturn = metadata
                    }
                }
                completion(metadataReturn, fileNamePath, error)
            }
        }

        let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)
        guard fetchAssets.count > 0, let asset = fetchAssets.firstObject else {
            return callCompletionWithError()
        }

        let extensionAsset = asset.originalFilename.pathExtension.uppercased()
        let creationDate = asset.creationDate ?? Date()
        let modificationDate = asset.modificationDate ?? Date()

        if asset.mediaType == PHAssetMediaType.image && (extensionAsset == "HEIC" || extensionAsset == "DNG") && CCUtility.getFormatCompatibility() {
            let fileName = (metadata.fileNameView as NSString).deletingPathExtension + ".jpg"
            metadata.contentType = "image/jpeg"
            fileNamePath = NSTemporaryDirectory() + fileName
            metadata.fileNameView = fileName
            if !metadata.isDirectoryE2EE {
                metadata.fileName = fileName
            }
            compatibilityFormat = true
        } else {
            fileNamePath = NSTemporaryDirectory() + metadata.fileNameView
        }

        guard let fileNamePath = fileNamePath else { return callCompletionWithError() }

        if asset.mediaType == PHAssetMediaType.image {

            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            if compatibilityFormat {
                options.deliveryMode = .opportunistic
            } else {
                options.deliveryMode = .highQualityFormat
            }
            options.isSynchronous = true
            if extensionAsset == "DNG" {
                options.version = PHImageRequestOptionsVersion.original
            }
            options.progressHandler = { progress, error, _, _ in
                print(progress)
                if error != nil { return callCompletionWithError() }
            }

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                guard var data = data else { return callCompletionWithError() }
                if compatibilityFormat {
                    guard let ciImage = CIImage(data: data), let colorSpace = ciImage.colorSpace, let dataJPEG = CIContext().jpegRepresentation(of: ciImage, colorSpace: colorSpace) else { return callCompletionWithError() }
                    data = dataJPEG
                }
                NCUtilityFileSystem.shared.deleteFile(filePath: fileNamePath)
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
                } catch { return callCompletionWithError() }
                metadata.creationDate = creationDate as NSDate
                metadata.date = modificationDate as NSDate
                metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNamePath)
                return callCompletionWithError(false)
            }

        } else if asset.mediaType == PHAssetMediaType.video {

            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = PHVideoRequestOptionsVersion.current
            options.progressHandler = { progress, error, _, _ in
                print(progress)
                if error != nil { return callCompletionWithError() }
            }

            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                if let asset = asset as? AVURLAsset {
                    NCUtilityFileSystem.shared.deleteFile(filePath: fileNamePath)
                    do {
                        try FileManager.default.copyItem(at: asset.url, to: URL(fileURLWithPath: fileNamePath))
                        metadata.creationDate = creationDate as NSDate
                        metadata.date = modificationDate as NSDate
                        metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNamePath)
                        return callCompletionWithError(false)
                    } catch { return callCompletionWithError() }
                } else if let asset = asset as? AVComposition, asset.tracks.count > 1, let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality), let viewController = viewController {
                    DispatchQueue.main.async {
                        hud.indicatorView = JGProgressHUDRingIndicatorView()
                        if let indicatorView = hud.indicatorView as? JGProgressHUDRingIndicatorView {
                            indicatorView.ringWidth = 1.5
                        }
                        hud.textLabel.text = NSLocalizedString("_exporting_video_", comment: "")
                        hud.show(in: viewController.view)
                        hud.tapOnHUDViewBlock = { _ in
                            exporter.cancelExport()
                        }
                    }
                    exporter.outputURL = URL(fileURLWithPath: fileNamePath)
                    exporter.outputFileType = AVFileType.mp4
                    exporter.shouldOptimizeForNetworkUse = true
                    exporter.exportAsynchronously {
                        DispatchQueue.main.async { hud.dismiss() }
                        if exporter.status == .completed {
                            metadata.creationDate = creationDate as NSDate
                            metadata.date = modificationDate as NSDate
                            metadata.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNamePath)
                            return callCompletionWithError(false)
                        } else { return callCompletionWithError() }
                    }
                    while exporter.status == AVAssetExportSession.Status.exporting || exporter.status == AVAssetExportSession.Status.waiting {
                        hud.progress = exporter.progress
                    }
                } else {
                    return callCompletionWithError()
                }
            }
        } else {
            return callCompletionWithError()
        }
    }

    private func createMetadataLivePhoto(metadata: tableMetadata,
                                         asset: PHAsset?,
                                         completion: @escaping (_ metadata: tableMetadata?) -> Void) {

        guard let asset = asset else { return completion(nil) }
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = PHImageRequestOptionsDeliveryMode.fastFormat
        options.isNetworkAccessAllowed = true
        let chunckSize = CCUtility.getChunkSize() * 1000000
        let ocId = NSUUID().uuidString
        let fileName = (metadata.fileName as NSString).deletingPathExtension + ".mov"
        let fileNamePath = CCUtility.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)!

        PHImageManager.default().requestLivePhoto(for: asset, targetSize: UIScreen.main.bounds.size, contentMode: PHImageContentMode.default, options: options) { livePhoto, _ in
            guard let livePhoto = livePhoto else { return completion(nil) }
            var videoResource: PHAssetResource?
            for resource in PHAssetResource.assetResources(for: livePhoto) where resource.type == PHAssetResourceType.pairedVideo {
                videoResource = resource
                break
            }
            guard let videoResource = videoResource else { return completion(nil) }
            NCUtilityFileSystem.shared.deleteFile(filePath: fileNamePath)
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: URL(fileURLWithPath: fileNamePath), options: nil) { error in
                if error != nil { return completion(nil) }
                let metadataLivePhoto = NCManageDatabase.shared.createMetadata(account: metadata.account,
                                                                               user: metadata.user,
                                                                               userId: metadata.userId,
                                                                               fileName: fileName,
                                                                               fileNameView: fileName,
                                                                               ocId: ocId,
                                                                               serverUrl: metadata.serverUrl,
                                                                               urlBase: metadata.urlBase,
                                                                               url: "",
                                                                               contentType: "",
                                                                               isLivePhoto: true)
                metadataLivePhoto.classFile = NKCommon.TypeClassFile.video.rawValue
                metadataLivePhoto.isExtractFile = true
                metadataLivePhoto.session = metadata.session
                metadataLivePhoto.sessionSelector = metadata.sessionSelector
                metadataLivePhoto.size = NCUtilityFileSystem.shared.getFileSize(filePath: fileNamePath)
                metadataLivePhoto.status = metadata.status
                metadataLivePhoto.chunk = chunckSize != 0 && metadata.size > chunckSize
                metadataLivePhoto.creationDate = metadata.creationDate
                metadataLivePhoto.date = metadata.date
                metadataLivePhoto.uploadDate = metadata.uploadDate
                return completion(NCManageDatabase.shared.addMetadata(metadataLivePhoto))
            }
        }
    }
}
