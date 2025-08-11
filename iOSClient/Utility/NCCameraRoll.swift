// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2022 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import Photos
import UIKit
import NextcloudKit
import AVFoundation

/// Structure representing an extracted asset result
struct ExtractedAsset {
    let metadata: tableMetadata
    let filePath: String
}

/// Protocol for camera roll extraction to allow mocking and flexibility
protocol CameraRollExtractor {
    func extractCameraRoll(from: [tableMetadata], progress: NCCameraRoll.ProgressHandler?) async -> [tableMetadata]
    func extractCameraRoll(from: tableMetadata) async -> [tableMetadata]
}

/// NCCameraRoll handles the extraction of image and video assets from the user's photo library
final class NCCameraRoll: CameraRollExtractor {
    let utilityFileSystem = NCUtilityFileSystem()
    let database = NCManageDatabase.shared

    /// Progress handler typealias to track extraction progress
    typealias ProgressHandler = (_ extracted: Int, _ total: Int, _ latest: tableMetadata?) -> Void

    /// Extracts a list of camera roll assets
    /// - Parameters:
    ///   - metadatas: An array of tableMetadata objects to extract
    ///   - progress: Optional closure to track progress
    /// - Returns: Array of extracted metadata
    func extractCameraRoll(from metadatas: [tableMetadata], progress: ProgressHandler? = nil) async -> [tableMetadata] {
        let total = metadatas.count
        var extracted: Int = 0
        var results: [tableMetadata] = []

        await withTaskGroup(of: [tableMetadata].self) { group in
            for metadata in metadatas {
                group.addTask {
                    let result = await self.extractCameraRoll(from: metadata)
                    return result
                }
            }

            for await result in group {
                for item in result {
                    extracted += 1
                    progress?(extracted, total, item)
                    nkLog(debug: "Extracted from camera roll: \(item.fileNameView)")
                }
                results.append(contentsOf: result)
            }
        }

        return results
    }

    /// Extracts a single camera roll asset
    /// - Parameter metadata: Metadata to extract
    /// - Returns: Extracted metadata, possibly including a paired Live Photo
    func extractCameraRoll(from metadata: tableMetadata) async -> [tableMetadata] {
        guard !metadata.isExtractFile else {
            return [metadata]
        }

        var metadatas: [tableMetadata] = []
        let metadataSource = metadata.detachedCopy()
        let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
            ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
            : NCGlobal.shared.chunkSizeMBCellular

        guard !metadataSource.assetLocalIdentifier.isEmpty else {
            let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadataSource.ocId,
                                                                             fileName: metadataSource.fileName,
                                                                             userId: metadataSource.userId,
                                                                             urlBase: metadata.urlBase)
            let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadataSource.fileNameView, mimeType: metadataSource.contentType, directory: false, account: metadataSource.account)

            metadataSource.contentType = results.mimeType
            metadataSource.iconName = results.iconName
            metadataSource.classFile = results.classFile
            metadataSource.typeIdentifier = results.typeIdentifier

            metadataSource.size = utilityFileSystem.getFileSize(filePath: filePath)

            if let date = utilityFileSystem.getFileCreationDate(filePath: filePath) {
                metadataSource.creationDate = date
            }
            if let date = utilityFileSystem.getFileModificationDate(filePath: filePath) {
                metadataSource.date = date
            }
            metadataSource.chunk = metadataSource.size > chunkSize ? chunkSize : 0
            metadataSource.e2eEncrypted = metadata.isDirectoryE2EE
            if metadataSource.chunk > 0 || metadataSource.e2eEncrypted {
                metadataSource.session = NCNetworking.shared.sessionUpload
            }
            metadataSource.isExtractFile = true

            if let metadata = self.database.addAndReturnMetadata(metadataSource) {
                metadatas.append(metadata)
            }
            return metadatas
        }

        do {
            let result = try await extractImageVideoFromAssetLocalIdentifier(
                metadata: metadataSource,
                modifyMetadataForUpload: true
            )

            let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.metadata.ocId,
                                                                                fileName: result.metadata.fileNameView,
                                                                                userId: result.metadata.userId,
                                                                                urlBase: result.metadata.urlBase)
            self.utilityFileSystem.moveFile(atPath: result.filePath, toPath: toPath)
            metadatas.append(result.metadata)

            let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadataSource.assetLocalIdentifier], options: nil)
            if result.metadata.isLivePhoto, let asset = fetchAssets.firstObject,
               let livePhotoMetadata = await createMetadataLivePhoto(metadata: result.metadata, asset: asset) {
                if let metadata = self.database.addAndReturnMetadata(livePhotoMetadata) {
                    metadatas.append(metadata)
                }
            }
        } catch {
            nkLog(error: "Error during extraction: \(error.localizedDescription), of filename: \(metadataSource.fileNameView)")
        }

        return metadatas
    }

    /// Wrapper to call the async `extractImageVideoFromAssetLocalIdentifierAsync` using a completion handler.
    /// - Parameters:
    ///   - metadata: The metadata to extract.
    ///   - modifyMetadataForUpload: Whether to modify the metadata before returning.
    ///   - completion: Completion handler with result or error.
    func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata, modifyMetadataForUpload: Bool, completion: @escaping (Result<ExtractedAsset, Error>) -> Void) {
        Task {
            do {
                let result = try await extractImageVideoFromAssetLocalIdentifier(
                    metadata: metadata,
                    modifyMetadataForUpload: modifyMetadataForUpload
                )
                completion(.success(result))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Extracts image or video data from a given asset identifier
    /// - Parameters:
    ///   - originalMetadata: Metadata describing the asset
    ///   - modifyMetadataForUpload: Whether to update metadata for upload and store it in the database
    /// - Returns: An `ExtractedAsset` containing the updated metadata and path to the extracted file
    func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata, modifyMetadataForUpload: Bool) async throws -> ExtractedAsset {
        // Determine the appropriate chunk size based on the current network connection
        let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
            ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
            : NCGlobal.shared.chunkSizeMBCellular

        // Fetch the PHAsset using the local identifier
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [metadata.assetLocalIdentifier],
            options: nil
        ).firstObject else {
            throw NSError(domain: "ExtractAssetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }

        // Determine file extension and prepare filename
        let ext = (asset.originalFilename as NSString).pathExtension.lowercased()
        let fileName = metadataUpdatedFilename(for: asset, original: metadata.fileNameView, ext: ext, native: metadata.nativeFormat)
        let filePath = NSTemporaryDirectory() + fileName

        metadata.fileName = fileName
        metadata.fileNameView = fileName
        metadata.serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName

        // Safely set the content type if available
        if let type = contentType(for: asset, ext: ext) {
            metadata.contentType = type
        }

        // Extract file data from asset
        switch asset.mediaType {
        case .image:
            try await extractImage(asset: asset, ext: ext, filePath: filePath, compatibilityFormat: !metadata.nativeFormat)
        case .video:
            try await extractVideo( asset: asset, filePath: filePath)
        default:
            throw NSError(domain: "ExtractAssetError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unsupported media type"])
        }

        // Populate metadata with extracted file info
        metadata.creationDate = (asset.creationDate ?? Date()) as NSDate
        metadata.date = (asset.modificationDate ?? Date()) as NSDate
        metadata.size = self.utilityFileSystem.getFileSize(filePath: filePath)

        // Optionally update metadata for upload and persist it
        if modifyMetadataForUpload {
            if let metadata = await updateMetadataForUploadAsync(metadata: metadata, size: Int(metadata.size), chunkSize: chunkSize) {
                return ExtractedAsset(metadata: metadata, filePath: filePath)
            } else {
                throw NSError(domain: "ExtractAssetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
            }
        } else {
            return ExtractedAsset(metadata: metadata, filePath: filePath)
        }
    }

    private func metadataUpdatedFilename(for asset: PHAsset, original: String, ext: String, native: Bool) -> String {
        if asset.mediaType == .image && (ext == "heic" || ext == "dng") && !native {
            return (original as NSString).deletingPathExtension + ".jpg"
        }
        return original
    }

    private func contentType(for asset: PHAsset, ext: String) -> String? {
        if asset.mediaType == .image && (ext == "heic" || ext == "dng") {
            return "image/jpeg"
        }
        return nil
    }

    private func updateMetadataForUpload(metadata: tableMetadata, size: Int, chunkSize: Int) -> tableMetadata? {
        metadata.chunk = size > chunkSize ? chunkSize : 0
        metadata.e2eEncrypted = metadata.isDirectoryE2EE
        if metadata.chunk > 0 || metadata.e2eEncrypted {
            metadata.session = NCNetworking.shared.sessionUpload
        }
        metadata.isExtractFile = true
        return self.database.addAndReturnMetadata(metadata)
    }

    private func updateMetadataForUploadAsync(metadata: tableMetadata, size: Int, chunkSize: Int) async -> tableMetadata? {
        metadata.chunk = size > chunkSize ? chunkSize : 0
        metadata.e2eEncrypted = metadata.isDirectoryE2EE
        if metadata.chunk > 0 || metadata.e2eEncrypted {
            metadata.session = NCNetworking.shared.sessionUpload
        }
        metadata.isExtractFile = true
        return await self.database.addAndReturnMetadataAsync(metadata)
    }

    private func extractImage(asset: PHAsset, ext: String, filePath: String, compatibilityFormat: Bool) async throws {
        let imageData: Data? = try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = compatibilityFormat ? .opportunistic : .highQualityFormat
            options.isSynchronous = true
            if ext == "dng" { options.version = .original }

            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "ExtractAssetError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Image data is nil"]))
                }
            }
        }

        var data = imageData!

        if compatibilityFormat {
            guard let ciImage = CIImage(data: data),
                  let colorSpace = ciImage.colorSpace,
                  let jpegData = CIContext().jpegRepresentation(of: ciImage, colorSpace: colorSpace)
            else {
                throw NSError(domain: "ExtractAssetError", code: 3, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
            }
            data = jpegData
        }

        self.utilityFileSystem.removeFile(atPath: filePath)
        try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
    }

    private func extractVideo(asset: PHAsset, filePath: String) async throws {
        let videoAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.version = .current

                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                    if let asset = asset {
                        continuation.resume(returning: asset)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ExtractAssetError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Video asset is nil"]))
                    }
                }
            }
        }

        self.utilityFileSystem.removeFile(atPath: filePath)

        if let urlAsset = videoAsset as? AVURLAsset {
            try FileManager.default.copyItem(at: urlAsset.url, to: URL(fileURLWithPath: filePath))
        } else if let composition = videoAsset as? AVComposition, composition.tracks.count > 1,
                  let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) {
            exporter.outputURL = URL(fileURLWithPath: filePath)
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true

            try await withCheckedThrowingContinuation { continuation in
                exporter.exportAsynchronously {
                    // Capture of 'exporter' with non-sendable type 'AVAssetExportSession' in a '@Sendable' closure I don't know how fix
                    if exporter.status == .completed {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(domain: "ExtractAssetError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Video export failed"]))
                    }
                }
            }
        } else {
            throw NSError(domain: "ExtractAssetError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unsupported video format"])
        }
    }

    /// Represents a camera roll extractor that creates metadata for Live Photos.
    /// This method is compatible with Swift 6, avoids non-Sendable captures,
    /// and performs safe background processing.
    private func createMetadataLivePhoto(metadata: tableMetadata, asset: PHAsset?) async -> tableMetadata? {
        guard let asset else {
            return nil
        }
        let session = NCSession.shared.getSession(account: metadata.account)
        let options = PHLivePhotoRequestOptions()
        let ocId = UUID().uuidString
        let fileName = (metadata.fileName as NSString).deletingPathExtension + ".mov"
        let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileName: fileName,
                                                                             userId: metadata.userId,
                                                                             urlBase: metadata.urlBase)
        let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
            ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
            : NCGlobal.shared.chunkSizeMBCellular

        options.deliveryMode = .fastFormat
        options.isNetworkAccessAllowed = true

        // UIScreen.main.bounds safely in Swift 6
        let screenSize = await MainActor.run {
            UIScreen.main.bounds.size
        }

        // Request the live photo from the asset
        let livePhoto = await withCheckedContinuation { (continuation: CheckedContinuation<PHLivePhoto?, Never>) in
            PHImageManager.default().requestLivePhoto(
                for: asset,
                targetSize: screenSize,
                contentMode: .default,
                options: options
            ) { photo, _ in
                continuation.resume(returning: photo)
            }
        }

        guard let livePhoto else { return nil }

        // Find the paired video component of the Live Photo
        let videoResource = PHAssetResource.assetResources(for: livePhoto)
            .first(where: { $0.type == .pairedVideo })
        guard let resource = videoResource else { return nil }

        utilityFileSystem.removeFile(atPath: fileNamePath)

        // Write video resource to file and create metadata
        return await withCheckedContinuation { (continuation: CheckedContinuation<tableMetadata?, Never>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: URL(fileURLWithPath: fileNamePath), options: nil ) { error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                NCManageDatabase.shared.createMetadata(fileName: fileName,
                                             ocId: ocId,
                                             serverUrl: metadata.serverUrl,
                                             session: session,
                                             sceneIdentifier: metadata.sceneIdentifier) { metadataLivePhoto in
                    metadataLivePhoto.livePhotoFile = metadata.fileName
                    metadataLivePhoto.isExtractFile = true
                    metadataLivePhoto.session = metadata.session
                    metadataLivePhoto.sessionSelector = metadata.sessionSelector
                    metadataLivePhoto.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                    metadataLivePhoto.status = metadata.status
                    metadataLivePhoto.chunk = metadataLivePhoto.size > chunkSize ? chunkSize : 0
                    metadataLivePhoto.e2eEncrypted = metadata.isDirectoryE2EE
                    if metadataLivePhoto.chunk > 0 || metadataLivePhoto.e2eEncrypted {
                        metadataLivePhoto.session = NCNetworking.shared.sessionUpload
                    }
                    metadataLivePhoto.creationDate = metadata.creationDate
                    metadataLivePhoto.date = metadata.date
                    metadataLivePhoto.uploadDate = metadata.uploadDate

                    continuation.resume(returning: metadataLivePhoto)
                }
            }
        }
    }
}

/// Mock implementation of CameraRollExtractor for unit testing
final class MockCameraRollExtractor: CameraRollExtractor {
    func extractCameraRoll(from metadatas: [tableMetadata], progress: NCCameraRoll.ProgressHandler?) async -> [tableMetadata] {
        progress?(metadatas.count, metadatas.count, metadatas.last)
        return metadatas
    }

    func extractCameraRoll(from metadata: tableMetadata) async -> [tableMetadata] {
        return [metadata]
    }
}

/*
 // SPDX-FileCopyrightText: Nextcloud GmbH
 // SPDX-FileCopyrightText: 2022-2025 Marino Faggiana
 // SPDX-License-Identifier: GPL-3.0-or-later

 import Foundation
 import Photos
 import UIKit
 import NextcloudKit
 import AVFoundation
 import UniformTypeIdentifiers

 /// Structure representing an extracted asset result
 struct ExtractedAsset {
     let metadata: tableMetadata
     let filePath: String
 }

 /// Protocol for camera roll extraction to allow mocking and flexibility
 protocol CameraRollExtractor {
     func extractCameraRoll(from: [tableMetadata], progress: NCCameraRoll.ProgressHandler?) async -> [tableMetadata]
     func extractCameraRoll(from: tableMetadata) async -> [tableMetadata]
 }

 /// Lightweight async semaphore to throttle PhotoKit requests
 actor AsyncSemaphore {
     private var value: Int
     init(_ value: Int) { self.value = max(1, value) }
     func wait() async { while value == 0 { await Task.yield() }; value -= 1 }
     func signal() { value += 1 }
 }

 /// NCCameraRoll handles the extraction of image and video assets from the user's photo library
 final class NCCameraRoll: CameraRollExtractor {
     let utilityFileSystem = NCUtilityFileSystem()
     let database = NCManageDatabase.shared

     /// Progress handler typealias to track extraction progress
     typealias ProgressHandler = (_ extracted: Int, _ total: Int, _ latest: tableMetadata?) -> Void

     // Limit concurrent PhotoKit requests to avoid stalls/timeouts on iCloud-backed assets
     private let semaphore = AsyncSemaphore(3)

     /// Extracts a list of camera roll assets
     /// - Parameters:
     ///   - metadatas: An array of tableMetadata objects to extract
     ///   - progress: Optional closure to track progress
     /// - Returns: Array of extracted metadata
     func extractCameraRoll(from metadatas: [tableMetadata], progress: ProgressHandler? = nil) async -> [tableMetadata] {
         let total = metadatas.count
         var extracted: Int = 0
         var results: [tableMetadata] = []

         await withTaskGroup(of: [tableMetadata].self) { group in
             for metadata in metadatas {
                 group.addTask { [weak self] in
                     guard let self else { return [] }
                     await self.semaphore.wait()
                     defer { self.semaphore.signal() }
                     let result = await self.extractCameraRoll(from: metadata)
                     return result
                 }
             }

             for await result in group {
                 for item in result {
                     extracted += 1
                     progress?(extracted, total, item)
                     nkLog(debug: "Extracted from camera roll: \(item.fileNameView)")
                 }
                 results.append(contentsOf: result)
             }
         }

         return results
     }

     /// Extracts a single camera roll asset
     /// - Parameter metadata: Metadata to extract
     /// - Returns: Extracted metadata, possibly including a paired Live Photo
     func extractCameraRoll(from metadata: tableMetadata) async -> [tableMetadata] {
         guard !metadata.isExtractFile else {
             return [metadata]
         }

         var metadatas: [tableMetadata] = []
         let metadataSource = metadata.detachedCopy()
         let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
             ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
             : NCGlobal.shared.chunkSizeMBCellular

         // Fast path: already exported to provider storage
         guard !metadataSource.assetLocalIdentifier.isEmpty else {
             let filePath = utilityFileSystem.getDirectoryProviderStorageOcId(metadataSource.ocId,
                                                                              fileName: metadataSource.fileName,
                                                                              userId: metadataSource.userId,
                                                                              urlBase: metadata.urlBase)

             // Robust MIME/type detection from filename
             let results = await NKTypeIdentifiers.shared.getInternalType(fileName: metadataSource.fileNameView,
                                                                          mimeType: metadataSource.contentType,
                                                                          directory: false,
                                                                          account: metadataSource.account)

             metadataSource.contentType = results.mimeType
             metadataSource.iconName = results.iconName
             metadataSource.classFile = results.classFile
             metadataSource.typeIdentifier = results.typeIdentifier

             metadataSource.size = utilityFileSystem.getFileSize(filePath: filePath)
             if let date = utilityFileSystem.getFileCreationDate(filePath: filePath) { metadataSource.creationDate = date }
             if let date = utilityFileSystem.getFileModificationDate(filePath: filePath) { metadataSource.date = date }
             metadataSource.chunk = metadataSource.size > chunkSize ? chunkSize : 0
             metadataSource.e2eEncrypted = metadata.isDirectoryE2EE
             if metadataSource.chunk > 0 || metadataSource.e2eEncrypted {
                 metadataSource.session = NCNetworking.shared.sessionUpload
             }
             metadataSource.isExtractFile = true

             if let metadata = self.database.addAndReturnMetadata(metadataSource) { metadatas.append(metadata) }
             return metadatas
         }

         do {
             let result = try await extractImageVideoFromAssetLocalIdentifier(
                 metadata: metadataSource,
                 modifyMetadataForUpload: true
             )

             let toPath = self.utilityFileSystem.getDirectoryProviderStorageOcId(result.metadata.ocId,
                                                                                 fileName: result.metadata.fileNameView,
                                                                                 userId: result.metadata.userId,
                                                                                 urlBase: result.metadata.urlBase)
             self.utilityFileSystem.moveFile(atPath: result.filePath, toPath: toPath)
             metadatas.append(result.metadata)

             let fetchAssets = PHAsset.fetchAssets(withLocalIdentifiers: [metadataSource.assetLocalIdentifier], options: nil)
             if result.metadata.isLivePhoto, let asset = fetchAssets.firstObject,
                let livePhotoMetadata = await createMetadataLivePhoto(metadata: result.metadata, asset: asset) {
                 if let metadata = self.database.addAndReturnMetadata(livePhotoMetadata) {
                     metadatas.append(metadata)
                 }
             }
         } catch {
             nkLog(error: "Error during extraction: \(error.localizedDescription), of filename: \(metadataSource.fileNameView)")
         }

         return metadatas
     }

     /// Wrapper to call the async `extractImageVideoFromAssetLocalIdentifier` using a completion handler.
     /// - Parameters:
     ///   - metadata: The metadata to extract.
     ///   - modifyMetadataForUpload: Whether to modify the metadata before returning.
     ///   - completion: Completion handler with result or error.
     func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata, modifyMetadataForUpload: Bool, completion: @escaping (Result<ExtractedAsset, Error>) -> Void) {
         Task {
             do {
                 let result = try await extractImageVideoFromAssetLocalIdentifier(
                     metadata: metadata,
                     modifyMetadataForUpload: modifyMetadataForUpload
                 )
                 completion(.success(result))
             } catch {
                 completion(.failure(error))
             }
         }
     }

     /// Extracts image or video data from a given asset identifier
     /// - Parameters:
     ///   - metadata: Metadata describing the asset (will be updated in-place)
     ///   - modifyMetadataForUpload: Whether to update metadata for upload and persist it
     /// - Returns: An `ExtractedAsset` containing the updated metadata and path to the extracted file
     func extractImageVideoFromAssetLocalIdentifier(metadata: tableMetadata, modifyMetadataForUpload: Bool) async throws -> ExtractedAsset {
         // Determine the appropriate chunk size based on the current network connection
         let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
             ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
             : NCGlobal.shared.chunkSizeMBCellular

         // Fetch the PHAsset using the local identifier
         guard let asset = PHAsset.fetchAssets(
             withLocalIdentifiers: [metadata.assetLocalIdentifier],
             options: nil
         ).firstObject else {
             throw NSError(domain: "ExtractAssetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
         }

         // Prefer resource-based detection for correct UTI/extension (screenshots, PNG, etc.)
         let resource = PHAssetResource.assetResources(for: asset).first { $0.type == .photo || $0.type == .fullSizePhoto } ?? PHAssetResource.assetResources(for: asset).first
         let detectedExt = resource.flatMap { URL(fileURLWithPath: $0.originalFilename).pathExtension.lowercased() } ?? asset.originalFilename.pathExtension.lowercased()
         let detectedUTI = resource?.uniformTypeIdentifier

         // Decide output filename and MIME
         let wantsCompatibilityJPEG = shouldForceJPEG(forUTI: detectedUTI, ext: detectedExt, native: metadata.nativeFormat == false)
         let targetExt: String = wantsCompatibilityJPEG ? "jpg" : (detectedExt.isEmpty ? safeExtension(fromUTI: detectedUTI) ?? "jpg" : detectedExt)
         let fileName = metadataUpdatedFilename(original: metadata.fileNameView, targetExt: targetExt)
         let filePath = NSTemporaryDirectory() + fileName

         metadata.fileName = fileName
         metadata.fileNameView = fileName
         metadata.serverUrlFileName = metadata.serverUrl + "/" + metadata.fileName
         metadata.contentType = wantsCompatibilityJPEG ? "image/jpeg" : mimeType(forUTI: detectedUTI, fallbackExt: targetExt) ?? metadata.contentType

         // Extract file data from asset using robust path:
         // 1) Try PHAssetResourceManager (works best for iCloud-backed photos and preserves originals)
         // 2) Fallback to requestImageDataAndOrientation
         switch asset.mediaType {
         case .image:
             do {
                 try await extractImageViaResource(resource: resource, filePath: filePath, forceJPEG: wantsCompatibilityJPEG)
             } catch {
                 nkLog(warning: "Resource extraction failed (\(error.localizedDescription)), falling back to imageData")
                 try await extractImageViaImageData(asset: asset, filePath: filePath, forceJPEG: wantsCompatibilityJPEG, ext: detectedExt)
             }
         case .video:
             try await extractVideo(asset: asset, filePath: filePath)
         default:
             throw NSError(domain: "ExtractAssetError", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unsupported media type"])
         }

         // Populate metadata with extracted file info
         metadata.creationDate = (asset.creationDate ?? Date()) as NSDate
         metadata.date = (asset.modificationDate ?? Date()) as NSDate
         metadata.size = self.utilityFileSystem.getFileSize(filePath: filePath)

         if modifyMetadataForUpload {
             if let metadata = await updateMetadataForUploadAsync(metadata: metadata, size: Int(metadata.size), chunkSize: chunkSize) {
                 return ExtractedAsset(metadata: metadata, filePath: filePath)
             } else {
                 throw NSError(domain: "ExtractAssetError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
             }
         } else {
             return ExtractedAsset(metadata: metadata, filePath: filePath)
         }
     }

     // MARK: - Filename/MIME helpers

     /// Build a new filename replacing only the extension
     private func metadataUpdatedFilename(original: String, targetExt: String) -> String {
         let base = (original as NSString).deletingPathExtension
         return base + "." + targetExt
     }

     /// Decide if we should transcode to JPEG for better compatibility
     private func shouldForceJPEG(forUTI uti: String?, ext: String, native: Bool) -> Bool {
         // Only force JPEG for HEIC/HEIF/DNG when caller requested non-native format
         guard native else {
             if let uti { return UTType(uti)?.conforms(to: .heic) == true || UTType(uti)?.conforms(to: .heif) == true || UTType(uti)?.conforms(to: .rawImage) == true }
             return ["heic", "heif", "dng"].contains(ext)
         }
         return false
     }

     /// Map UTI to MIME type with fallback to extension
     private func mimeType(forUTI uti: String?, fallbackExt: String) -> String? {
         if let uti, let type = UTType(uti) { return type.preferredMIMEType }
         switch fallbackExt.lowercased() {
         case "png": return "image/png"
         case "jpg", "jpeg": return "image/jpeg"
         case "gif": return "image/gif"
         case "tif", "tiff": return "image/tiff"
         case "bmp": return "image/bmp"
         case "heic": return "image/heic"
         case "heif": return "image/heif"
         default: return nil
         }
     }

     /// Derive a safe extension from UTI
     private func safeExtension(fromUTI uti: String?) -> String? {
         guard let uti, let type = UTType(uti), let ext = type.preferredFilenameExtension else { return nil }
         return ext
     }

     // MARK: - Image extraction strategies

     /// Primary path: write the original resource to disk and optionally transcode to JPEG
     private func extractImageViaResource(resource: PHAssetResource?, filePath: String, forceJPEG: Bool) async throws {
         // Download original resource to temporary file
         let tmpPath = filePath + ".orig"
         self.utilityFileSystem.removeFile(atPath: tmpPath)

         guard let resource else { throw NSError(domain: "ExtractAssetError", code: 10, userInfo: [NSLocalizedDescriptionKey: "Missing asset resource"]) }

         try await withThrowingTaskGroup(of: Void.self) { group in
             group.addTask { [weak self] in
                 guard let self else { return }
                 let options = PHAssetResourceRequestOptions()
                 options.isNetworkAccessAllowed = true
                 options.deliveryMode = .highQualityFormat

                 try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                     PHAssetResourceManager.default().writeData(for: resource, toFile: URL(fileURLWithPath: tmpPath), options: options) { error in
                         if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                     }
                 }
             }
             // Optional timeout safeguard to avoid stalling forever on corrupted iCloud items
             group.addTask { try await Task.sleep(nanoseconds: 180 * 1_000_000_000) }

             do { try await group.next() } catch {
                 // Cancel on timeout and propagate
                 group.cancelAll()
                 throw error
             }
             group.cancelAll()
         }

         if forceJPEG {
             // Transcode original to JPEG
             let data = try Data(contentsOf: URL(fileURLWithPath: tmpPath))
             guard let ciImage = CIImage(data: data), let colorSpace = ciImage.colorSpace, let jpeg = CIContext().jpegRepresentation(of: ciImage, colorSpace: colorSpace) else {
                 throw NSError(domain: "ExtractAssetError", code: 11, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed (resource path)"])
             }
             try jpeg.write(to: URL(fileURLWithPath: filePath), options: .atomic)
             self.utilityFileSystem.removeFile(atPath: tmpPath)
         } else {
             // Keep native
             self.utilityFileSystem.removeFile(atPath: filePath)
             try FileManager.default.moveItem(atPath: tmpPath, toPath: filePath)
         }
     }

     /// Fallback path: request image data via PhotoKit and optionally transcode to JPEG
     private func extractImageViaImageData(asset: PHAsset, filePath: String, forceJPEG: Bool, ext: String) async throws {
         let data: Data = try await withCheckedThrowingContinuation { continuation in
             let options = PHImageRequestOptions()
             options.isNetworkAccessAllowed = true
             options.deliveryMode = .highQualityFormat
             options.isSynchronous = true
             // Preserve RAW when present
             if ext == "dng" { options.version = .original }

             PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                 if let data { continuation.resume(returning: data) }
                 else { continuation.resume(throwing: NSError(domain: "ExtractAssetError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Image data is nil"])) }
             }
         }

         var outData = data
         if forceJPEG {
             guard let ciImage = CIImage(data: data), let colorSpace = ciImage.colorSpace, let jpeg = CIContext().jpegRepresentation(of: ciImage, colorSpace: colorSpace) else {
                 throw NSError(domain: "ExtractAssetError", code: 3, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
             }
             outData = jpeg
         }

         self.utilityFileSystem.removeFile(atPath: filePath)
         try outData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
     }

     // MARK: - Video extraction

     private func extractVideo(asset: PHAsset, filePath: String) async throws {
         let videoAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
             // Request on main to match PhotoKit expectations
             DispatchQueue.main.async {
                 let options = PHVideoRequestOptions()
                 options.isNetworkAccessAllowed = true
                 options.version = .current

                 PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { asset, _, _ in
                     if let asset { continuation.resume(returning: asset) }
                     else { continuation.resume(throwing: NSError(domain: "ExtractAssetError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Video asset is nil"])) }
                 }
             }
         }

         self.utilityFileSystem.removeFile(atPath: filePath)

         if let urlAsset = videoAsset as? AVURLAsset {
             try FileManager.default.copyItem(at: urlAsset.url, to: URL(fileURLWithPath: filePath))
         } else if let composition = videoAsset as? AVComposition, composition.tracks.count > 1,
                   let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) {
             exporter.outputURL = URL(fileURLWithPath: filePath)
             exporter.outputFileType = .mp4
             exporter.shouldOptimizeForNetworkUse = true

             // Avoid Sendable complaints by staying on the main actor and using unsafe continuation
             try await MainActor.run {
                 try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
                     exporter.exportAsynchronously {
                         switch exporter.status {
                         case .completed:
                             continuation.resume()
                         case .failed, .cancelled:
                             let err = exporter.error ?? NSError(domain: "ExtractAssetError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Video export failed"])
                             continuation.resume(throwing: err)
                         default:
                             // Treat unexpected state as failure
                             let err = NSError(domain: "ExtractAssetError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Video export ended in state \(exporter.status.rawValue)"])
                             continuation.resume(throwing: err)
                         }
                     }
                 }
             }
         } else {
             throw NSError(domain: "ExtractAssetError", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unsupported video format"])
         }
     }

     // MARK: - Upload metadata updates

     private func updateMetadataForUpload(metadata: tableMetadata, size: Int, chunkSize: Int) -> tableMetadata? {
         metadata.chunk = size > chunkSize ? chunkSize : 0
         metadata.e2eEncrypted = metadata.isDirectoryE2EE
         if metadata.chunk > 0 || metadata.e2eEncrypted {
             metadata.session = NCNetworking.shared.sessionUpload
         }
         metadata.isExtractFile = true
         return self.database.addAndReturnMetadata(metadata)
     }

     private func updateMetadataForUploadAsync(metadata: tableMetadata, size: Int, chunkSize: Int) async -> tableMetadata? {
         metadata.chunk = size > chunkSize ? chunkSize : 0
         metadata.e2eEncrypted = metadata.isDirectoryE2EE
         if metadata.chunk > 0 || metadata.e2eEncrypted {
             metadata.session = NCNetworking.shared.sessionUpload
         }
         metadata.isExtractFile = true
         return await self.database.addAndReturnMetadataAsync(metadata)
     }

     // MARK: - Live Photo support

     /// Represents a camera roll extractor that creates metadata for Live Photos.
     /// This method is compatible with Swift 6, avoids non-Sendable captures,
     /// and performs safe background processing.
     private func createMetadataLivePhoto(metadata: tableMetadata, asset: PHAsset?) async -> tableMetadata? {
         guard let asset else { return nil }
         let session = NCSession.shared.getSession(account: metadata.account)
         let options = PHLivePhotoRequestOptions()
         let ocId = UUID().uuidString
         let fileName = (metadata.fileName as NSString).deletingPathExtension + ".mov"
         let fileNamePath = utilityFileSystem.getDirectoryProviderStorageOcId(ocId, fileName: fileName,
                                                                              userId: metadata.userId,
                                                                              urlBase: metadata.urlBase)
         let chunkSize = NCNetworking.shared.networkReachability == .reachableEthernetOrWiFi
             ? NCGlobal.shared.chunkSizeMBEthernetOrWiFi
             : NCGlobal.shared.chunkSizeMBCellular

         options.deliveryMode = .fastFormat
         options.isNetworkAccessAllowed = true

         // Larger target size to ensure paired video resource is discoverable
         let targetSize = PHImageManagerMaximumSize

         let livePhoto = await withCheckedContinuation { (continuation: CheckedContinuation<PHLivePhoto?, Never>) in
             PHImageManager.default().requestLivePhoto(
                 for: asset,
                 targetSize: targetSize,
                 contentMode: .default,
                 options: options
             ) { photo, _ in
                 continuation.resume(returning: photo)
             }
         }

         guard let livePhoto else { return nil }

         let videoResource = PHAssetResource.assetResources(for: livePhoto).first(where: { $0.type == .pairedVideo })
         guard let resource = videoResource else { return nil }

         utilityFileSystem.removeFile(atPath: fileNamePath)

         return await withCheckedContinuation { (continuation: CheckedContinuation<tableMetadata?, Never>) in
             let reqOptions = PHAssetResourceRequestOptions()
             reqOptions.isNetworkAccessAllowed = true

             PHAssetResourceManager.default().writeData(for: resource, toFile: URL(fileURLWithPath: fileNamePath), options: reqOptions ) { error in
                 guard error == nil else {
                     continuation.resume(returning: nil)
                     return
                 }
                 NCManageDatabase.shared.createMetadata(fileName: fileName,
                                              ocId: ocId,
                                              serverUrl: metadata.serverUrl,
                                              session: session,
                                              sceneIdentifier: metadata.sceneIdentifier) { metadataLivePhoto in
                     metadataLivePhoto.livePhotoFile = metadata.fileName
                     metadataLivePhoto.isExtractFile = true
                     metadataLivePhoto.session = metadata.session
                     metadataLivePhoto.sessionSelector = metadata.sessionSelector
                     metadataLivePhoto.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                     metadataLivePhoto.status = metadata.status
                     metadataLivePhoto.chunk = metadataLivePhoto.size > chunkSize ? chunkSize : 0
                     metadataLivePhoto.e2eEncrypted = metadata.isDirectoryE2EE
                     if metadataLivePhoto.chunk > 0 || metadataLivePhoto.e2eEncrypted {
                         metadataLivePhoto.session = NCNetworking.shared.sessionUpload
                     }
                     metadataLivePhoto.creationDate = metadata.creationDate
                     metadataLivePhoto.date = metadata.date
                     metadataLivePhoto.uploadDate = metadata.uploadDate

                     continuation.resume(returning: metadataLivePhoto)
                 }
             }
         }
     }
 }

 /// Mock implementation of CameraRollExtractor for unit testing
 final class MockCameraRollExtractor: CameraRollExtractor {
     func extractCameraRoll(from metadatas: [tableMetadata], progress: NCCameraRoll.ProgressHandler?) async -> [tableMetadata] {
         progress?(metadatas.count, metadatas.count, metadatas.last)
         return metadatas
     }

     func extractCameraRoll(from metadata: tableMetadata) async -> [tableMetadata] {
         return [metadata]
     }
 }

 */
