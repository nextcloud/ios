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

    func extractCameraRoll(from transfer: TableTransfer, completition: @escaping (_ transfers: [TableTransfer]) -> Void) {
        var transfers: [TableTransfer] = []
        let transferSource = TableTransfer.init(value: transfer)
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }
        guard !transfer.isExtractFile else { return  completition([transferSource]) }

        guard !transferSource.assetLocalIdentifier.isEmpty else {
            let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(transferSource.id, fileNameView: transferSource.fileName)
            transferSource.size = utilityFileSystem.getFileSize(filePath: filePath)
            let results = NextcloudKit.shared.nkCommonInstance.getInternalType(fileName: transferSource.fileNameView, mimeType: transferSource.contentType, directory: false, account: transferSource.account)
            transferSource.contentType = results.mimeType
            transferSource.iconName = results.iconName
            transferSource.classFile = results.classFile
            if let date = utilityFileSystem.getFileCreationDate(filePath: filePath) as? Date {
                transferSource.creationDate = date
            }
            if let date = utilityFileSystem.getFileModificationDate(filePath: filePath) as? Date {
                transferSource.modificationDate = date
            }
            if transferSource.size > chunkSize {
                transferSource.chunk = chunkSize
            } else {
                transferSource.chunk = 0
            }
            //transferSource.e2eEncrypted = transfer.isDirectoryE2EE
            if transferSource.chunk > 0 || transferSource.e2eEncrypted {
                transferSource.sessionItendifier = NCNetworking.shared.sessionUpload
            }
            transferSource.isExtractFile = true

            transfers.append(self.database.addTransfer(transferSource))

            return completition(transfers)
        }

        extractImageVideoFromAssetLocalIdentifier(transfer: transferSource, modifyTransfer: true) { transfer, fileNamePath, error in
            if let transfer, let fileNamePath = fileNamePath, !error {
                transfers.append(transfer)
                let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(transfer.id, fileNameView: transfer.fileNameView)
                self.utilityFileSystem.moveFile(atPath: fileNamePath, toPath: toPath)
                let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [transferSource.assetLocalIdentifier], options: nil)
                if !transfer.livePhotoFile.isEmpty, fetchAssets.count > 0 {
                    self.createMetadataLivePhoto(transfer: transfer, asset: fetchAssets.firstObject) { transfer in
                        if let transfer {
                            transfers.append(transfer)
                        }
                        completition(transfers)
                    }
                } else {
                    completition(transfers)
                }
            } else {
                completition(transfers)
            }
        }
    }

    func extractCameraRoll(from transfer: TableTransfer) async -> [TableTransfer] {
        await withUnsafeContinuation({ continuation in
            extractCameraRoll(from: transfer) { transfers in
                continuation.resume(returning: transfers)
            }
        })
    }

    func extractImageVideoFromAssetLocalIdentifier(transfer: TableTransfer,
                                                   modifyTransfer: Bool,
                                                   completion: @escaping (_ transfer: TableTransfer?, _ fileNamePath: String?, _ error: Bool) -> Void) {

        var fileNamePath: String?
        var transfer = transfer
        var compatibilityFormat: Bool = false
        var chunkSize = NCGlobal.shared.chunkSizeMBCellular
        if NCNetworking.shared.networkReachability == NKCommon.TypeReachability.reachableEthernetOrWiFi {
            chunkSize = NCGlobal.shared.chunkSizeMBEthernetOrWiFi
        }

        func callCompletionWithError(_ error: Bool = true) {
            if error {
                completion(nil, nil, true)
            } else {
                if modifyTransfer {
                    if transfer.size > chunkSize {
                        transfer.chunk = chunkSize
                    } else {
                        transfer.chunk = 0
                    }
                    //transfer.e2eEncrypted = transfer.isDirectoryE2EE
                    if transfer.chunk > 0 || transfer.e2eEncrypted {
                        transfer.sessionItendifier = NCNetworking.shared.sessionUpload
                    }
                    transfer.isExtractFile = true
                    transfer = self.database.addTransfer(transfer)
                }
                completion(transfer, fileNamePath, error)
            }
        }

        let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [transfer.assetLocalIdentifier], options: nil)
        guard fetchAssets.count > 0, let asset = fetchAssets.firstObject else {
            return callCompletionWithError()
        }

        let extensionAsset = asset.originalFilename.pathExtension.lowercased()
        let creationDate = asset.creationDate ?? Date()
        let modificationDate = asset.modificationDate ?? Date()

        if asset.mediaType == PHAssetMediaType.image && (extensionAsset == "heic" || extensionAsset == "dng") && !transfer.nativeFormat {
            let fileName = (transfer.fileNameView as NSString).deletingPathExtension + ".jpg"
            transfer.contentType = "image/jpeg"
            fileNamePath = NSTemporaryDirectory() + fileName
            transfer.fileNameView = fileName
            transfer.fileName = fileName
            compatibilityFormat = true
        } else {
            fileNamePath = NSTemporaryDirectory() + transfer.fileNameView
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
                transfer.creationDate = creationDate
                transfer.modificationDate = modificationDate
                transfer.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
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
                        transfer.creationDate = creationDate
                        transfer.modificationDate = modificationDate
                        transfer.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                        return callCompletionWithError(false)
                    } catch { return callCompletionWithError() }
                } else if let asset = asset as? AVComposition, asset.tracks.count > 1, let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) {
                    exporter.outputURL = URL(fileURLWithPath: fileNamePath)
                    exporter.outputFileType = AVFileType.mp4
                    exporter.shouldOptimizeForNetworkUse = true
                    exporter.exportAsynchronously {
                        if exporter.status == .completed {
                            transfer.creationDate = creationDate
                            transfer.modificationDate = modificationDate
                            transfer.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
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

    private func createMetadataLivePhoto(transfer: TableTransfer,
                                         asset: PHAsset?,
                                         completion: @escaping (_ transfer: TableTransfer?) -> Void) {

        guard let asset = asset else { return completion(nil) }
        let options = PHLivePhotoRequestOptions()
        options.deliveryMode = PHImageRequestOptionsDeliveryMode.fastFormat
        options.isNetworkAccessAllowed = true
        let id = NSUUID().uuidString
        let fileName = (transfer.fileName as NSString).deletingPathExtension + ".mov"
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(id, fileNameView: fileName)
        let sessionItendifier = transfer.e2eEncrypted ? NCNetworking.shared.sessionUpload : transfer.sessionItendifier

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
                let transferLivePhoto = self.database.createTransferLivePhotoFileVideoForUpload(transfer: transfer,
                                                                                                id: id,
                                                                                                fileName: fileName,
                                                                                                size: self.utilityFileSystem.getFileSize(filePath: fileNamePath),
                                                                                                sessionItendifier: sessionItendifier)
                return completion(self.database.addTransfer(transferLivePhoto))
            }
        }
    }
}
