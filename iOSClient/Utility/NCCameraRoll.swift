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

        for item in metadatas {
            // Call the single-item extractor directly; it already does a detachedCopy() when needed
            let result = await self.extractCameraRoll(from: item)
            for metadata in result {
                extracted += 1
                progress?(extracted, total, metadata)
                nkLog(debug: "Extracted from camera roll: \(metadata.fileNameView)")
            }
            results.append(contentsOf: result)
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
            if result.metadata.isLivePhoto,
               let asset = fetchAssets.firstObject,
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
        metadata.serverUrlFileName = utilityFileSystem.createServerUrl(serverUrl: metadata.serverUrl, fileName: metadata.fileName)

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
        let imageData: Data = try await withCheckedThrowingContinuation { continuation in
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

        // Transform only if compatibilityFormat is requested
        let finalData: Data
        if compatibilityFormat {
            guard let ciImage = CIImage(data: imageData),
                  let colorSpace = ciImage.colorSpace,
                  let jpegData = CIContext().jpegRepresentation(of: ciImage, colorSpace: colorSpace)
            else {
                throw NSError(domain: "ExtractAssetError", code: 3, userInfo: [NSLocalizedDescriptionKey: "JPEG conversion failed"])
            }
            finalData = jpegData
        } else {
            finalData = imageData
        }

        try finalData.write(to: URL(fileURLWithPath: filePath), options: .atomic)
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
            nonisolated(unsafe) let localExporter = exporter

            try await withCheckedThrowingContinuation { continuation in
                localExporter.exportAsynchronously {
                    // Avoid capturing non-Sendable 'AVAssetExportSession' by using a nonisolated(unsafe) local binding
                    let status = localExporter.status
                    if status == .completed {
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
        nonisolated(unsafe) let session = NCSession.shared.getSession(account: metadata.account)
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

        guard let livePhoto else {
            return nil
        }

        // Find the paired video component of the Live Photo
        let videoResource = PHAssetResource.assetResources(for: livePhoto)
            .first(where: { $0.type == .pairedVideo })
        guard let resource = videoResource else {
            return nil
        }

        do {
            try FileManager.default.removeItem(atPath: fileNamePath)
        } catch {
            print(error)
        }

        // Capture only Sendable values needed inside the @Sendable closure
        let capturedServerUrl = metadata.serverUrl
        let capturedSceneIdentifier = metadata.sceneIdentifier
        let capturedLivePhotoFile = metadata.fileName
        let capturedSession = metadata.session
        let capturedSessionSelector = metadata.sessionSelector
        let capturedStatus = metadata.status
        let capturedIsDirectoryE2EE = metadata.isDirectoryE2EE
        let capturedCreationDate = metadata.creationDate
        let capturedDate = metadata.date
        let capturedUploadDate = metadata.uploadDate

        // Write video resource to file and create metadata
        return await withCheckedContinuation { (continuation: CheckedContinuation<tableMetadata?, Never>) in
            PHAssetResourceManager.default().writeData(for: resource, toFile: URL(fileURLWithPath: fileNamePath), options: nil ) { error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                NCManageDatabase.shared.createMetadata(fileName: fileName,
                                             ocId: ocId,
                                             serverUrl: capturedServerUrl,
                                             session: session,
                                             sceneIdentifier: capturedSceneIdentifier) { metadataLivePhoto in
                    metadataLivePhoto.livePhotoFile = capturedLivePhotoFile
                    metadataLivePhoto.isExtractFile = true
                    metadataLivePhoto.session = capturedSession
                    metadataLivePhoto.sessionSelector = capturedSessionSelector
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: fileNamePath)
                        metadataLivePhoto.size = attributes[FileAttributeKey.size] as? Int64 ?? 0
                    } catch {
                        print(error)
                    }
                    metadataLivePhoto.status = capturedStatus
                    metadataLivePhoto.chunk = metadataLivePhoto.size > chunkSize ? chunkSize : 0
                    metadataLivePhoto.e2eEncrypted = capturedIsDirectoryE2EE
                    if metadataLivePhoto.chunk > 0 || metadataLivePhoto.e2eEncrypted {
                        metadataLivePhoto.session = NCNetworking.shared.sessionUpload
                    }
                    metadataLivePhoto.creationDate = capturedCreationDate
                    metadataLivePhoto.date = capturedDate
                    metadataLivePhoto.uploadDate = capturedUploadDate

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
