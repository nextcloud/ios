// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import Testing
@testable import Nextcloud

@Suite("NCCameraRoll image format conversion")
struct NCCameraRollTests {

    @Test("Animated and lossless formats retain their filenames")
    func formatsPreserved() {
        for fileName in ["animation.gif", "image.png", "animation.webp", "image.tiff", "image.jpg"] {
            let fileExtension = (fileName as NSString).pathExtension

            #expect(!NCCameraRoll.shouldConvertToJPEG(fileExtension: fileExtension, nativeFormat: false))
            #expect(
                NCCameraRoll.outputFileName(
                    for: fileName,
                    sourceFileExtension: fileExtension,
                    nativeFormat: false
                ) == fileName
            )
        }
    }

    @Test("Compatibility formats are converted to JPEG")
    func compatibilityFormatsConverted() {
        for fileName in ["image.heic", "image.heif", "image.dng"] {
            let fileExtension = (fileName as NSString).pathExtension

            #expect(NCCameraRoll.shouldConvertToJPEG(fileExtension: fileExtension, nativeFormat: false))
            #expect(
                NCCameraRoll.outputFileName(
                    for: fileName,
                    sourceFileExtension: fileExtension,
                    nativeFormat: false
                ) == "image.jpg"
            )
        }
    }

    @Test("Native format preserves HEIC, HEIF and RAW filenames")
    func nativeFormatsPreserved() {
        for fileName in ["image.heic", "image.heif", "image.dng"] {
            let fileExtension = (fileName as NSString).pathExtension

            #expect(!NCCameraRoll.shouldConvertToJPEG(fileExtension: fileExtension, nativeFormat: true))
            #expect(
                NCCameraRoll.outputFileName(
                    for: fileName,
                    sourceFileExtension: fileExtension,
                    nativeFormat: true
                ) == fileName
            )
        }
    }

    @Test("Generated upload names keep their base name")
    func generatedNameConverted() {
        #expect(
            NCCameraRoll.outputFileName(
                for: "2026-08-04 09-30-00.heic",
                sourceFileExtension: "heic",
                nativeFormat: false
            ) == "2026-08-04 09-30-00.jpg"
        )
    }

    @Test("Video passthrough retains its original container")
    func videoContainerPreserved() {
        #expect(NCCameraRoll.videoOutputFileType(fileExtension: "mov") == .mov)
        #expect(NCCameraRoll.videoOutputFileType(fileExtension: "MP4") == .mp4)
        #expect(NCCameraRoll.videoOutputFileType(fileExtension: "m4v") == .m4v)
        #expect(NCCameraRoll.videoOutputFileType(fileExtension: "jpg") == nil)
    }

    @Test("Concurrent extractions use distinct temporary paths")
    func extractionTemporaryPathsAreUnique() {
        let directory = FileManager.default.temporaryDirectory
        let firstURL = NCCameraRoll.extractionTemporaryURL(
            fileName: "26-08-04 10-51-42 7473.jpg",
            ocId: "camera-roll-transfer",
            directory: directory
        )
        let secondURL = NCCameraRoll.extractionTemporaryURL(
            fileName: "26-08-04 10-51-42 7473.jpg",
            ocId: "camera-roll-transfer",
            directory: directory
        )

        #expect(firstURL != secondURL)
        #expect(firstURL.deletingLastPathComponent() == directory)
        #expect(firstURL.pathExtension == "uploading")
        #expect(firstURL.lastPathComponent.contains("camera-roll-transfer"))
    }
}
