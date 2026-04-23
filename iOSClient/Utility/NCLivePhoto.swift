// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Alexander Pagliaro
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
@preconcurrency import AVFoundation
import Photos
import NextcloudKit
import UniformTypeIdentifiers
import ImageIO

final class NCLivePhoto {
    // MARK: - Public

    typealias LivePhotoResources = (pairedImage: URL, pairedVideo: URL)

    /// Returns the paired image and video for the given PHLivePhoto.
    public class func extractResources(from livePhoto: PHLivePhoto, completion: @escaping (LivePhotoResources?) -> Void) {
        queue.async {
            shared.extractResources(from: livePhoto, completion: completion)
        }
    }

    /// Generates a PHLivePhoto from an image and video.
    /// Also returns the paired image and video resources.
    public class func generate(from imageURL: URL?, videoURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (PHLivePhoto?, LivePhotoResources?) -> Void) {
        queue.async {
            Task {
                await shared.generateAsync(from: imageURL, videoURL: videoURL, progress: progress, completion: completion)
            }
        }
    }

    /// Saves a Live Photo to the Photo Library using the paired image and video.
    public class func saveToLibrary(_ resources: LivePhotoResources, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()

            creationRequest.addResource(with: .pairedVideo, fileURL: resources.pairedVideo, options: options)
            creationRequest.addResource(with: .photo, fileURL: resources.pairedImage, options: options)
        }, completionHandler: { success, error in
            if let error {
                print(error)
            }
            completion(success)
        })
    }

    // MARK: - Private

    private static let shared = NCLivePhoto()
    private static let queue = DispatchQueue(label: "com.limit-point.LivePhotoQueue", attributes: .concurrent)

    /// Minimal wrapper used to pass Objective-C / AVFoundation reference types through @Sendable closures.
    private final class UnsafeSendableBox<Value>: @unchecked Sendable {
        let value: Value

        init(_ value: Value) {
            self.value = value
        }
    }

    private lazy var cacheDirectory: URL? = {
        guard let cacheDirectoryURL = try? FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else {
            return nil
        }

        let fullDirectory = cacheDirectoryURL.appendingPathComponent("com.limit-point.LivePhoto", isDirectory: true)

        if !FileManager.default.fileExists(atPath: fullDirectory.path) {
            try? FileManager.default.createDirectory(at: fullDirectory, withIntermediateDirectories: true, attributes: nil)
        }

        return fullDirectory
    }()

    deinit {
        clearCache()
    }

    /// Generates the JPEG key photo from the video still-image time if available,
    /// otherwise falls back to the middle frame of the video.
    private func generateKeyPhoto(from videoURL: URL) async -> URL? {
        let videoAsset = AVURLAsset(url: videoURL)

        var percent: Float = 0.5

        if let stillImageTime = await videoAsset.stillImageTimeAsync(),
           let duration = try? await videoAsset.load(.duration),
           duration.value != 0 {
            percent = Float(stillImageTime.value) / Float(duration.value)
        }

        guard let imageFrame = await videoAsset.getAssetFrameAsync(percent: percent) else {
            return nil
        }

        guard let jpegData = imageFrame.jpegData(compressionQuality: 1) else {
            return nil
        }

        guard let url = cacheDirectory?
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg") else {
            return nil
        }

        do {
            try jpegData.write(to: url, options: .atomic)
            return url
        } catch {
            print(error)
            return nil
        }
    }

    private func clearCache() {
        guard let cacheDirectory else {
            return
        }

        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    /// Generates the paired image and paired video and then builds a PHLivePhoto from them.
    private func generateAsync(from imageURL: URL?, videoURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (PHLivePhoto?, LivePhotoResources?) -> Void) async {
        guard let cacheDirectory else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }

        let assetIdentifier = UUID().uuidString

        let keyPhotoURLSource: URL?
        if let imageURL {
            keyPhotoURLSource = imageURL
        } else {
            keyPhotoURLSource = await generateKeyPhoto(from: videoURL)
        }

        guard
            let keyPhotoURL = keyPhotoURLSource,
            let pairedImageURL = addAssetID(
                assetIdentifier,
                toImage: keyPhotoURL,
                saveTo: cacheDirectory.appendingPathComponent(assetIdentifier).appendingPathExtension("jpg")
            )
        else {
            DispatchQueue.main.async {
                completion(nil, nil)
            }
            return
        }

        addAssetID(
            assetIdentifier,
            toVideo: videoURL,
            saveTo: cacheDirectory.appendingPathComponent(assetIdentifier).appendingPathExtension("mov"),
            progress: progress
        ) { pairedVideoURL in
            guard let pairedVideoURL else {
                DispatchQueue.main.async {
                    completion(nil, nil)
                }
                return
            }

            _ = PHLivePhoto.request(
                withResourceFileURLs: [pairedVideoURL, pairedImageURL],
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFit
            ) { livePhoto, info in
                if let isDegraded = info[PHLivePhotoInfoIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                DispatchQueue.main.async {
                    completion(livePhoto, (pairedImageURL, pairedVideoURL))
                }
            }
        }
    }

    /// Extracts the paired photo and paired video resources from a PHLivePhoto into the target directory.
    private func extractResources(from livePhoto: PHLivePhoto, to directoryURL: URL, completion: @escaping (LivePhotoResources?) -> Void) {
        let assetResources = PHAssetResource.assetResources(for: livePhoto)
        let group = DispatchGroup()

        var keyPhotoURL: URL?
        var videoURL: URL?

        for resource in assetResources {
            let buffer = NSMutableData()
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            group.enter()

            PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
                buffer.append(data)
            }) { error in
                if error == nil {
                    if resource.type == .pairedVideo {
                        videoURL = self.saveAssetResource(resource, to: directoryURL, resourceData: buffer as Data)
                    } else if resource.type == .photo {
                        keyPhotoURL = self.saveAssetResource(resource, to: directoryURL, resourceData: buffer as Data)
                    }
                } else {
                    print(error as Any)
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard let pairedPhotoURL = keyPhotoURL, let pairedVideoURL = videoURL else {
                completion(nil)
                return
            }

            completion((pairedPhotoURL, pairedVideoURL))
        }
    }

    private func extractResources(from livePhoto: PHLivePhoto, completion: @escaping (LivePhotoResources?) -> Void) {
        guard let cacheDirectory else {
            completion(nil)
            return
        }

        extractResources(from: livePhoto, to: cacheDirectory, completion: completion)
    }

    /// Saves a PHAssetResource to disk and returns the destination URL.
    private func saveAssetResource(_ resource: PHAssetResource, to directory: URL, resourceData: Data) -> URL? {
        let type = UTType(resource.uniformTypeIdentifier)
        let fileExtension = type?.preferredFilenameExtension ?? "dat"

        let fileURL = directory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)

        do {
            try resourceData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            print("Could not save resource \(resource) to filepath \(fileURL)")
            return nil
        }
    }

    /// Adds the Live Photo asset identifier metadata to the JPEG image.
    func addAssetID(_ assetIdentifier: String, toImage imageURL: URL, saveTo destinationURL: URL) -> URL? {
        guard
            let imageDestination = CGImageDestinationCreateWithURL(
                destinationURL as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ),
            let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
            var imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [AnyHashable: Any]
        else {
            return nil
        }

        let assetIdentifierKey = "17"
        let assetIdentifierInfo = [assetIdentifierKey: assetIdentifier]
        imageProperties[kCGImagePropertyMakerAppleDictionary] = assetIdentifierInfo

        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, imageProperties as CFDictionary)
        CGImageDestinationFinalize(imageDestination)

        return destinationURL
    }

    /// Adds the Live Photo asset identifier metadata to the MOV video.
    func addAssetID(_ assetIdentifier: String, toVideo videoURL: URL, saveTo destinationURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (URL?) -> Void) {
        Task {
            await addAssetIDAsync(
                assetIdentifier,
                toVideo: videoURL,
                saveTo: destinationURL,
                progress: progress,
                completion: completion
            )
        }
    }

    /// Rewrites the input video into a new MOV file including the Live Photo metadata.
    private func addAssetIDAsync(_ assetIdentifier: String, toVideo videoURL: URL, saveTo destinationURL: URL, progress: @escaping (CGFloat) -> Void, completion: @escaping (URL?) -> Void) async {
        let videoAsset = AVURLAsset(url: videoURL)
        let frameCount = await videoAsset.countFramesAsync(exact: false)

        do {
            let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
            guard let videoTrack = videoTracks.first else {
                completion(nil)
                return
            }

            let naturalSize = try await videoTrack.load(.naturalSize)
            let preferredTransform = try await videoTrack.load(.preferredTransform)

            let assetWriter = try AVAssetWriter(outputURL: destinationURL, fileType: .mov)
            let assetWriterBox = UnsafeSendableBox(assetWriter)

            let videoReader = try AVAssetReader(asset: videoAsset)
            let videoReaderBox = UnsafeSendableBox(videoReader)

            let videoReaderSettings: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA as UInt32)
            ]

            let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoReaderSettings)
            videoReader.add(videoReaderOutput)
            let videoReaderOutputBox = UnsafeSendableBox(videoReaderOutput)

            let videoWriterInput = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: naturalSize.width,
                    AVVideoHeightKey: naturalSize.height
                ]
            )
            videoWriterInput.transform = preferredTransform
            videoWriterInput.expectsMediaDataInRealTime = true
            assetWriter.add(videoWriterInput)
            let videoWriterInputBox = UnsafeSendableBox(videoWriterInput)

            var audioReader: AVAssetReader?
            var audioReaderOutput: AVAssetReaderOutput?
            var audioWriterInput: AVAssetWriterInput?

            let audioTracks = try await videoAsset.loadTracks(withMediaType: .audio)
            if let audioTrack = audioTracks.first {
                let localAudioReader = try AVAssetReader(asset: videoAsset)
                let localAudioReaderOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
                localAudioReader.add(localAudioReaderOutput)

                let localAudioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
                localAudioWriterInput.expectsMediaDataInRealTime = false
                assetWriter.add(localAudioWriterInput)

                audioReader = localAudioReader
                audioReaderOutput = localAudioReaderOutput
                audioWriterInput = localAudioWriterInput
            }

            let audioReaderBox = audioReader.map(UnsafeSendableBox.init)
            let audioReaderOutputBox = audioReaderOutput.map(UnsafeSendableBox.init)
            let audioWriterInputBox = audioWriterInput.map(UnsafeSendableBox.init)

            let assetIdentifierMetadata = metadataForAssetID(assetIdentifier)
            let stillImageTimeMetadataAdapter = createMetadataAdaptorForStillImageTime()

            assetWriter.metadata = [assetIdentifierMetadata]
            assetWriter.add(stillImageTimeMetadataAdapter.assetWriterInput)

            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: .zero)

            let stillImagePercent: Float = 0.5
            let stillImageRange = await videoAsset.makeStillImageTimeRangeAsync(
                percent: stillImagePercent,
                inFrameCount: frameCount
            )

            stillImageTimeMetadataAdapter.append(
                AVTimedMetadataGroup(
                    items: [metadataItemForStillImageTime()],
                    timeRange: stillImageRange
                )
            )

            let completionQueue = DispatchQueue(label: "com.nextcloud.livephoto.finish")
            let completionQueueBox = UnsafeSendableBox(completionQueue)

            let state = LivePhotoWritingState(audioPresent: audioReader != nil)
            let stateBox = UnsafeSendableBox(state)

            func completeIfNeeded() {
                completionQueueBox.value.async {
                    guard stateBox.value.tryBeginFinishIfPossible() else {
                        return
                    }

                    assetWriterBox.value.finishWriting {
                        let resultURL = assetWriterBox.value.status == .completed ? destinationURL : nil
                        completion(resultURL)
                    }
                }
            }

            if videoReader.startReading() {
                videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.nextcloud.livephoto.videoWriterInputQueue")) {
                    while videoWriterInputBox.value.isReadyForMoreMediaData {
                        if let sampleBuffer = videoReaderOutputBox.value.copyNextSampleBuffer() {
                            let currentFrameCount = stateBox.value.incrementVideoFrameCount()

                            if frameCount > 0 {
                                let percent = CGFloat(currentFrameCount) / CGFloat(frameCount)
                                progress(percent)
                            } else {
                                progress(0)
                            }

                            if !videoWriterInputBox.value.append(sampleBuffer) {
                                print("Cannot write video: \(assetWriterBox.value.error?.localizedDescription ?? "unknown error")")
                                videoReaderBox.value.cancelReading()
                                videoWriterInputBox.value.markAsFinished()
                                stateBox.value.markVideoFinished()
                                completeIfNeeded()
                                break
                            }
                        } else {
                            videoWriterInputBox.value.markAsFinished()
                            stateBox.value.markVideoFinished()
                            completeIfNeeded()
                            break
                        }
                    }
                }
            } else {
                stateBox.value.markVideoFinished()
                completeIfNeeded()
            }

            if let audioReaderBox, let audioReaderOutputBox, let audioWriterInputBox {
                if audioReaderBox.value.startReading() {
                    audioWriterInputBox.value.requestMediaDataWhenReady(on: DispatchQueue(label: "com.nextcloud.livephoto.audioWriterInputQueue")) {
                        while audioWriterInputBox.value.isReadyForMoreMediaData {
                            guard let sampleBuffer = audioReaderOutputBox.value.copyNextSampleBuffer() else {
                                audioWriterInputBox.value.markAsFinished()
                                stateBox.value.markAudioFinished()
                                completeIfNeeded()
                                return
                            }

                            if !audioWriterInputBox.value.append(sampleBuffer) {
                                print("Cannot write audio: \(assetWriterBox.value.error?.localizedDescription ?? "unknown error")")
                                audioReaderBox.value.cancelReading()
                                audioWriterInputBox.value.markAsFinished()
                                stateBox.value.markAudioFinished()
                                completeIfNeeded()
                                return
                            }
                        }
                    }
                } else {
                    stateBox.value.markAudioFinished()
                    completeIfNeeded()
                }
            } else {
                stateBox.value.markAudioFinished()
                completeIfNeeded()
            }

        } catch {
            print(error)
            completion(nil)
        }
    }

    /// Builds the QuickTime metadata item containing the Live Photo asset identifier.
    private func metadataForAssetID(_ assetIdentifier: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        let keyContentIdentifier = "com.apple.quicktime.content.identifier"
        let keySpaceQuickTimeMetadata = "mdta"

        item.key = keyContentIdentifier as (NSCopying & NSObjectProtocol)?
        item.keySpace = AVMetadataKeySpace(rawValue: keySpaceQuickTimeMetadata)
        item.value = assetIdentifier as (NSCopying & NSObjectProtocol)?
        item.dataType = "com.apple.metadata.datatype.UTF-8"

        return item
    }

    /// Creates the metadata adaptor used to write the still-image-time metadata group.
    private func createMetadataAdaptorForStillImageTime() -> AVAssetWriterInputMetadataAdaptor {
        let keyStillImageTime = "com.apple.quicktime.still-image-time"
        let keySpaceQuickTimeMetadata = "mdta"

        let specification: NSDictionary = [
            kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as NSString:
                "\(keySpaceQuickTimeMetadata)/\(keyStillImageTime)",
            kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as NSString:
                "com.apple.metadata.datatype.int8"
        ]

        var description: CMFormatDescription?
        CMMetadataFormatDescriptionCreateWithMetadataSpecifications(
            allocator: kCFAllocatorDefault,
            metadataType: kCMMetadataFormatType_Boxed,
            metadataSpecifications: [specification] as CFArray,
            formatDescriptionOut: &description
        )

        let input = AVAssetWriterInput(
            mediaType: .metadata,
            outputSettings: nil,
            sourceFormatHint: description
        )

        return AVAssetWriterInputMetadataAdaptor(assetWriterInput: input)
    }

    /// Builds the QuickTime metadata item representing the still-image-time marker.
    private func metadataItemForStillImageTime() -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        let keyStillImageTime = "com.apple.quicktime.still-image-time"
        let keySpaceQuickTimeMetadata = "mdta"

        item.key = keyStillImageTime as (NSCopying & NSObjectProtocol)?
        item.keySpace = AVMetadataKeySpace(rawValue: keySpaceQuickTimeMetadata)
        item.value = 0 as (NSCopying & NSObjectProtocol)?
        item.dataType = "com.apple.metadata.datatype.int8"

        return item
    }
}

// MARK: - LivePhotoWritingState

private final class LivePhotoWritingState {
    private let lock = NSLock()

    private var writingVideoFinished = false
    private var writingAudioFinished = false
    private var didFinishWriting = false
    private var currentFrameCount = 0

    init(audioPresent: Bool) {
        writingAudioFinished = !audioPresent
    }

    func incrementVideoFrameCount() -> Int {
        lock.lock()
        defer { lock.unlock() }

        currentFrameCount += 1
        return currentFrameCount
    }

    func markVideoFinished() {
        lock.lock()
        writingVideoFinished = true
        lock.unlock()
    }

    func markAudioFinished() {
        lock.lock()
        writingAudioFinished = true
        lock.unlock()
    }

    func tryBeginFinishIfPossible() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard writingVideoFinished, writingAudioFinished, !didFinishWriting else {
            return false
        }

        didFinishWriting = true
        return true
    }
}

fileprivate extension AVAsset {

    /// Returns the estimated or exact frame count for the first video track.
    func countFramesAsync(exact: Bool) async -> Int {
        do {
            let videoTracks = try await loadTracks(withMediaType: .video)
            guard let videoTrack = videoTracks.first else {
                return 0
            }

            let duration = try await load(.duration)
            let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)

            var frameCount = Int(CMTimeGetSeconds(duration) * Float64(nominalFrameRate))

            if exact {
                frameCount = 0

                guard let videoReader = try? AVAssetReader(asset: self) else {
                    return 0
                }

                let videoReaderOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
                videoReader.add(videoReaderOutput)

                videoReader.startReading()

                while true {
                    let sampleBuffer = videoReaderOutput.copyNextSampleBuffer()
                    if sampleBuffer == nil {
                        break
                    }
                    frameCount += 1
                }

                videoReader.cancelReading()
            }

            return frameCount
        } catch {
            print(error)
            return 0
        }
    }

    /// Returns the still-image-time metadata timestamp if present.
    func stillImageTimeAsync() async -> CMTime? {
        do {
            let metadataTracks = try await loadTracks(withMediaType: .metadata)
            guard let metadataTrack = metadataTracks.first else {
                return nil
            }

            guard let metadataReader = try? AVAssetReader(asset: self) else {
                return nil
            }

            let metadataReaderOutput = AVAssetReaderTrackOutput(track: metadataTrack, outputSettings: nil)
            metadataReader.add(metadataReaderOutput)
            metadataReader.startReading()

            let keyStillImageTime = "com.apple.quicktime.still-image-time"
            let keySpaceQuickTimeMetadata = "mdta"

            while let sampleBuffer = metadataReaderOutput.copyNextSampleBuffer() {
                guard CMSampleBufferGetNumSamples(sampleBuffer) != 0 else {
                    continue
                }

                let group = AVTimedMetadataGroup(sampleBuffer: sampleBuffer)

                for item in group?.items ?? [] {
                    if item.key as? String == keyStillImageTime,
                       item.keySpace?.rawValue == keySpaceQuickTimeMetadata {
                        metadataReader.cancelReading()
                        return group?.timeRange.start
                    }
                }
            }

            metadataReader.cancelReading()
            return nil
        } catch {
            print(error)
            return nil
        }
    }

    /// Builds the time range used to mark the still image inside the video metadata timeline.
    func makeStillImageTimeRangeAsync(percent: Float, inFrameCount: Int = 0) async -> CMTimeRange {
        do {
            let duration = try await load(.duration)

            var frameCount = inFrameCount
            if frameCount == 0 {
                frameCount = await countFramesAsync(exact: true)
            }

            guard frameCount > 0 else {
                return CMTimeRange(start: .zero, duration: .zero)
            }

            var time = duration
            let frameDurationValue = Int64(Float(time.value) / Float(frameCount))
            time.value = Int64(Float(time.value) * percent)

            return CMTimeRange(
                start: time,
                duration: CMTime(value: frameDurationValue, timescale: time.timescale)
            )
        } catch {
            print(error)
            return CMTimeRange(start: .zero, duration: .zero)
        }
    }

    /// Extracts a frame image from the asset at the given percentage of its duration.
    func getAssetFrameAsync(percent: Float) async -> UIImage? {
        let imageGenerator = AVAssetImageGenerator(asset: self)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 100)
        imageGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 100)

        do {
            let duration = try await load(.duration)
            var time = duration
            time.value = Int64(Float(time.value) * percent)

            var actualTime = CMTime.zero
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: &actualTime)

            return UIImage(cgImage: imageRef)
        } catch {
            print("Image generation failed with error \(error)")
            return nil
        }
    }
}

extension NCLivePhoto {
    func setLivePhoto(metadata1: tableMetadata, metadata2: tableMetadata) {
        Task {
            let capabilities = await NKCapabilities.shared.getCapabilities(for: metadata1.account)

            guard capabilities.serverVersionMajor >= NCGlobal.shared.nextcloudVersion28 else {
                return
            }

            if metadata1.livePhotoFile.isEmpty, !metadata2.fileName.isEmpty {
                let serverUrlfileNamePath = metadata1.urlBase + metadata1.path + metadata1.fileName

                _ = await NextcloudKit.shared.setLivephotoAsync(
                    serverUrlfileNamePath: serverUrlfileNamePath,
                    livePhotoFile: metadata2.fileName,
                    account: metadata1.account
                ) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                            account: metadata1.account,
                            path: serverUrlfileNamePath,
                            name: "setLivephoto"
                        )
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                }
            }

            if metadata2.livePhotoFile.isEmpty, !metadata1.fileName.isEmpty {
                let serverUrlfileNamePath = metadata2.urlBase + metadata2.path + metadata2.fileName

                _ = await NextcloudKit.shared.setLivephotoAsync(
                    serverUrlfileNamePath: serverUrlfileNamePath,
                    livePhotoFile: metadata1.fileName,
                    account: metadata2.account
                ) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                            account: metadata2.account,
                            path: serverUrlfileNamePath,
                            name: "setLivephoto"
                        )
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                }
            }
        }
    }
}
