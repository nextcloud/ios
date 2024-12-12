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
import Photos
import UIKit
import NextcloudKit

class NCCameraRoll: NSObject {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    func extractCameraRoll(from metadata: tableMetadata, completition: @escaping (_ metadatas: [tableMetadata]) -> Void) {
        var metadatas: [tableMetadata] = []
        let metadataSource = tableMetadata.init(value: metadata)
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }
        guard !metadata.isExtractFile else { return  completition([metadataSource]) }

        guard !metadataSource.assetLocalIdentifier.isEmpty else {
            let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadataSource.ocId, fileNameView: metadataSource.fileName)
            metadataSource.size = utilityFileSystem.getFileSize(filePath: filePath)
            let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: metadataSource.fileNameView, mimeType: metadataSource.contentType, directory: false, account: metadataSource.account)
            metadataSource.contentType = results.mimeType
            metadataSource.iconName = results.iconName
            metadataSource.classFile = results.classFile
            if let date = utilityFileSystem.getFileCreationDate(filePath: filePath) {
                metadataSource.creationDate = date
            }
            if let date = utilityFileSystem.getFileModificationDate(filePath: filePath) {
                metadataSource.date = date
            }
            if metadataSource.size > chunkSize {
                metadataSource.chunk = chunkSize
            } else {
                metadataSource.chunk = 0
            }
            metadataSource.e2eEncrypted = metadata.isDirectoryE2EE
            if metadataSource.chunk > 0 || metadataSource.e2eEncrypted {
                metadataSource.session = NCNetworking.shared.sessionUpload
            }
            metadataSource.isExtractFile = true

            metadatas.append(self.database.addMetadata(metadataSource))

            return completition(metadatas)
        }

        extractImageVideoFromAssetLocalIdentifier(metadata: metadataSource, modifyMetadataForUpload: true) { metadata, fileNamePath, error in
            if let metadata = metadata, let fileNamePath = fileNamePath, !error {
                metadatas.append(metadata)
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
                self.utilityFileSystem.moveFile(atPath: fileNamePath, toPath: toPath)
                let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadataSource.assetLocalIdentifier], options: nil)
                if metadata.isLivePhoto, fetchAssets.count > 0 {
                    self.createMetadataLivePhoto(metadata: metadata, asset: fetchAssets.firstObject) { metadata in
                        if let metadata {
                            metadatas.append(self.database.addMetadata(metadata))
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

    func extractCameraRoll(from metadata: tableMetadata) async -> [tableMetadata] {
        await withUnsafeContinuation({ continuation in
            extractCameraRoll(from: metadata) { metadatas in
                continuation.resume(returning: metadatas)
            }
        })
    }

    func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata,
                                                   modifyMetadataForUpload: Bool,
                                                   completion: @escaping (_ metadata: tableMetadata?, _ fileNamePath: String?, _ error: Bool) -> Void) {

        var fileNamePath: String?
        var metadata = metadata
        var compatibilityFormat: Bool = false
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }

        func callCompletionWithError(_ error: Bool = true) {
            if error {
                completion(nil, nil, true)
            } else {
                if modifyMetadataForUpload {
                    if metadata.size > chunkSize {
                        metadata.chunk = chunkSize
                    } else {
                        metadata.chunk = 0
                    }
                    metadata.e2eEncrypted = metadata.isDirectoryE2EE
                    if metadata.chunk > 0 || metadata.e2eEncrypted {
                        metadata.session = NCNetworking.shared.sessionUpload
                    }
                    metadata.isExtractFile = true
                    metadata = self.database.addMetadata(metadata)
                }
                completion(metadata, fileNamePath, error)
            }
        }

        let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadata.assetLocalIdentifier], options: nil)
        guard fetchAssets.count > 0, let asset = fetchAssets.firstObject else {
            return callCompletionWithError()
        }

        let extensionAsset = asset.originalFilename.pathExtension.uppercased()
        let creationDate = asset.creationDate ?? Date()
        let modificationDate = asset.modificationDate ?? Date()

        if asset.mediaType == PHAssetMediaType.image && (extensionAsset == "HEIC" || extensionAsset == "DNG") && !metadata.nativeFormat {
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
                self.utilityFileSystem.removeFile(atPath: fileNamePath)
                do {
                    try data.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
                } catch { return callCompletionWithError() }
                metadata.creationDate = creationDate as NSDate
                metadata.date = modificationDate as NSDate
                metadata.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
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
                    self.utilityFileSystem.removeFile(atPath: fileNamePath)
                    do {
                        try FileManager.default.copyItem(at: asset.url, to: URL(fileURLWithPath: fileNamePath))
                        metadata.creationDate = creationDate as NSDate
                        metadata.date = modificationDate as NSDate
                        metadata.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                        return callCompletionWithError(false)
                    } catch { return callCompletionWithError() }
                } else if let asset = asset as? AVComposition, asset.tracks.count > 1, let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
                    exporter.outputURL = URL(fileURLWithPath: fileNamePath)
                    exporter.outputFileType = AVFileType.mp4
                    exporter.shouldOptimizeForNetworkUse = true
                    exporter.exportAsynchronously {
                        if exporter.status == .completed {
                            metadata.creationDate = creationDate as NSDate
                            metadata.date = modificationDate as NSDate
                            metadata.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                            return callCompletionWithError(false)
                        } else { return callCompletionWithError() }
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
        let ocId = NSUUID().uuidString
        let fileName = (metadata.fileName as NSString).deletingPathExtension + ".mov"
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileNameView: fileName)
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }

        PHImageManager.default().requestLivePhoto(for: asset, targetSize: UIScreen.main.bounds.size, contentMode: PHImageContentMode.default, options: options) { livePhoto, _ in
            guard let livePhoto = livePhoto else { return completion(nil) }
            var videoResource: PHAssetResource?
            for resource in PHAssetResource.assetResources(for: livePhoto) where resource.type == PHAssetResourceType.pairedVideo {
                videoResource = resource
                break
            }
            guard let videoResource = videoResource else { return completion(nil) }
            self.utilityFileSystem.removeFile(atPath: fileNamePath)
            PHAssetResourceManager.default().writeData(for: videoResource, toFile: URL(fileURLWithPath: fileNamePath), options: nil) { error in
                guard error == nil else { return completion(nil) }
                let session = NCSession.shared.getSession(account: metadata.account)
                let metadataLivePhoto = self.database.createMetadata(fileName: fileName,
                                                                     fileNameView: fileName,
                                                                     ocId: ocId,
                                                                     serverUrl: metadata.serverUrl,
                                                                     url: "",
                                                                     contentType: "",
                                                                     session: session,
                                                                     sceneIdentifier: metadata.sceneIdentifier)
                metadataLivePhoto.livePhotoFile = metadata.fileName
                metadataLivePhoto.classFile = NKCommon.TypeClassFile.video.rawValue
                metadataLivePhoto.isExtractFile = true
                metadataLivePhoto.session = metadata.session
                metadataLivePhoto.sessionSelector = metadata.sessionSelector
                metadataLivePhoto.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                metadataLivePhoto.status = metadata.status
                if metadataLivePhoto.size > chunkSize {
                    metadataLivePhoto.chunk = chunkSize
                } else {
                    metadataLivePhoto.chunk = 0
                }
                metadataLivePhoto.e2eEncrypted = metadata.isDirectoryE2EE
                if metadataLivePhoto.chunk > 0 || metadataLivePhoto.e2eEncrypted {
                    metadataLivePhoto.session = NCNetworking.shared.sessionUpload
                }
                metadataLivePhoto.creationDate = metadata.creationDate
                metadataLivePhoto.date = metadata.date
                metadataLivePhoto.uploadDate = metadata.uploadDate

                return completion(self.database.addMetadata(metadataLivePhoto))
            }
        }
    }
}
