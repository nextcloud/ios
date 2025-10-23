//
//  NCUtility.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/06/18.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import NextcloudKit
import PDFKit
import Accelerate
import CoreMedia
import Photos

final class NCUtility: NSObject, Sendable {
    let utilityFileSystem = NCUtilityFileSystem()
    let global = NCGlobal.shared

    func isTypeFileRichDocument(_ metadata: tableMetadata) -> Bool {
        let fileExtension = (metadata.fileNameView as NSString).pathExtension
        guard let capabilities = NCNetworking.shared.capabilities[metadata.account],
              !fileExtension.isEmpty,
              let mimeType = UTType(tag: fileExtension.uppercased(), tagClass: .filenameExtension, conformingTo: nil)?.identifier else {
            return false
        }

        /// contentype
        if !capabilities.richDocumentsMimetypes.filter({ $0.contains(metadata.contentType) || $0.contains("text/plain") }).isEmpty {
            return true
        }

        /// mimetype
        if !capabilities.richDocumentsMimetypes.isEmpty && mimeType.components(separatedBy: ".").count > 2 {
            let mimeTypeArray = mimeType.components(separatedBy: ".")
            let mimeType = mimeTypeArray[mimeTypeArray.count - 2] + "." + mimeTypeArray[mimeTypeArray.count - 1]
            if !capabilities.richDocumentsMimetypes.filter({ $0.contains(mimeType) }).isEmpty {
                return true
            }
        }
        return false
    }

    func editorsDirectEditing(account: String, contentType: String) -> [String] {
        var names: [String] = []
        let capabilities = NCNetworking.shared.capabilities[account]

        capabilities?.directEditingEditors.forEach { editor in
            editor.mimetypes.forEach { mimetype in
                if mimetype == contentType {
                    names.append(editor.name)
                }
                // HARDCODE
                // https://github.com/nextcloud/text/issues/913
                if mimetype == "text/markdown" && contentType == "text/x-markdown" {
                    names.append(editor.name)
                }
                if contentType == "text/html" {
                    names.append(editor.name)
                }
            }

            editor.optionalMimetypes.forEach { mimetype in
                if mimetype == contentType {
                    names.append(editor.name)
                }
            }
        }

        return Array(Set(names))
    }

    func getCustomUserAgentNCText() -> String {
        if UIDevice.current.userInterfaceIdiom == .phone {
            // NOTE: Hardcoded (May 2022)
            // Tested for iPhone SE (1st), iOS 12 iPhone Pro Max, iOS 15.4
            // 605.1.15 = WebKit build version
            // 15E148 = frozen iOS build number according to: https://chromestatus.com/feature/4558585463832576
            return userAgent + " " + "AppleWebKit/605.1.15 Mobile/15E148"
        } else {
            return userAgent
        }
    }

    func getCustomUserAgentOnlyOffice() -> String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")!
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "Mozilla/5.0 (iPad) Nextcloud-iOS/\(appVersion)"
        } else {
            return "Mozilla/5.0 (iPhone) Mobile Nextcloud-iOS/\(appVersion)"
        }
    }

    func isQuickLookDisplayable(metadata: tableMetadata) -> Bool {
        return true
    }

    func ocIdToFileId(ocId: String?) -> String? {
        guard let ocId = ocId else { return nil }
        let items = ocId.components(separatedBy: "oc")

        if items.count < 2 { return nil }
        guard let intFileId = Int(items[0]) else { return nil }
        return String(intFileId)
    }

    func splitOcId(_ ocId: String) -> (fileId: String?, instanceId: String?) {
        let parts = ocId.components(separatedBy: "oc")
        guard parts.count == 2 else {
            return (nil, nil)
        }
        return (parts[0], "oc" + parts[1])
    }

    /// Pads a numeric fileId with leading zeros to reach 8 characters.
    func paddedFileId(_ fileId: String) -> String {
        if fileId.count >= 8 { return fileId }
        let zeros = String(repeating: "0", count: 8 - fileId.count)
        return zeros + fileId
    }

    func getLivePhotoOcId(metadata: tableMetadata) -> String? {
        if let instanceId = splitOcId(metadata.ocId).instanceId {
            return paddedFileId(metadata.livePhotoFile) + instanceId
        }
        return nil
    }

    func getVersionBuild() -> String {
        if let dictionary = Bundle.main.infoDictionary,
           let version = dictionary["CFBundleShortVersionString"],
           let build = dictionary["CFBundleVersion"] {
            return "\(version).\(build)"
        }
        return ""
    }

    func getVersionMaintenance() -> String {
        if let dictionary = Bundle.main.infoDictionary,
           let version = dictionary["CFBundleShortVersionString"] {
            return "\(version)"
        }
        return ""
    }

    /*
     Facebook's comparison algorithm:
     */

    func compare(tolerance: Float, expected: Data, observed: Data) throws -> Bool {
        enum customError: Error {
            case unableToGetUIImageFromData
            case unableToGetCGImageFromData
            case unableToGetColorSpaceFromCGImage
            case imagesHasDifferentSizes
            case unableToInitializeContext
        }

        guard let expectedUIImage = UIImage(data: expected), let observedUIImage = UIImage(data: observed) else {
            throw customError.unableToGetUIImageFromData
        }
        guard let expectedCGImage = expectedUIImage.cgImage, let observedCGImage = observedUIImage.cgImage else {
            throw customError.unableToGetCGImageFromData
        }
        guard let expectedColorSpace = expectedCGImage.colorSpace, let observedColorSpace = observedCGImage.colorSpace else {
            throw customError.unableToGetColorSpaceFromCGImage
        }
        if expectedCGImage.width != observedCGImage.width || expectedCGImage.height != observedCGImage.height {
            throw customError.imagesHasDifferentSizes
        }
        let imageSize = CGSize(width: expectedCGImage.width, height: expectedCGImage.height)
        let numberOfPixels = Int(imageSize.width * imageSize.height)

        // Checking that our `UInt32` buffer has same number of bytes as image has.
        let bytesPerRow = min(expectedCGImage.bytesPerRow, observedCGImage.bytesPerRow)
        assert(MemoryLayout<UInt32>.stride == bytesPerRow / Int(imageSize.width))

        let expectedPixels = UnsafeMutablePointer<UInt32>.allocate(capacity: numberOfPixels)
        let observedPixels = UnsafeMutablePointer<UInt32>.allocate(capacity: numberOfPixels)

        let expectedPixelsRaw = UnsafeMutableRawPointer(expectedPixels)
        let observedPixelsRaw = UnsafeMutableRawPointer(observedPixels)

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let expectedContext = CGContext(data: expectedPixelsRaw, width: Int(imageSize.width), height: Int(imageSize.height),
                                              bitsPerComponent: expectedCGImage.bitsPerComponent, bytesPerRow: bytesPerRow,
                                              space: expectedColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            expectedPixels.deallocate()
            observedPixels.deallocate()
            throw customError.unableToInitializeContext
        }
        guard let observedContext = CGContext(data: observedPixelsRaw, width: Int(imageSize.width), height: Int(imageSize.height),
                                              bitsPerComponent: observedCGImage.bitsPerComponent, bytesPerRow: bytesPerRow,
                                              space: observedColorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            expectedPixels.deallocate()
            observedPixels.deallocate()
            throw customError.unableToInitializeContext
        }

        expectedContext.draw(expectedCGImage, in: CGRect(origin: .zero, size: imageSize))
        observedContext.draw(observedCGImage, in: CGRect(origin: .zero, size: imageSize))

        let expectedBuffer = UnsafeBufferPointer(start: expectedPixels, count: numberOfPixels)
        let observedBuffer = UnsafeBufferPointer(start: observedPixels, count: numberOfPixels)

        var isEqual = true
        if tolerance == 0 {
            isEqual = expectedBuffer.elementsEqual(observedBuffer)
        } else {
            // Go through each pixel in turn and see if it is different
            var numDiffPixels = 0
            for pixel in 0 ..< numberOfPixels where expectedBuffer[pixel] != observedBuffer[pixel] {
                // If this pixel is different, increment the pixel diff count and see if we have hit our limit.
                numDiffPixels += 1
                let percentage = 100 * Float(numDiffPixels) / Float(numberOfPixels)
                if percentage > tolerance {
                    isEqual = false
                    break
                }
            }
        }

        expectedPixels.deallocate()
        observedPixels.deallocate()

        return isEqual
    }

    func getLocation(latitude: Double, longitude: Double, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        let llocation = CLLocation(latitude: latitude, longitude: longitude)

        if let location = NCManageDatabase.shared.getLocationFromLatAndLong(latitude: latitude, longitude: longitude) {
            completion(location)
        } else {
            geocoder.reverseGeocodeLocation(llocation) { placemarks, error in
                if error == nil, let placemark = placemarks?.first {
                    let locationComponents: [String] = [placemark.name, placemark.locality, placemark.country]
                        .compactMap {$0}

                    let location = locationComponents.joined(separator: ", ")

                    NCManageDatabase.shared.addGeocoderLocation(location, latitude: latitude, longitude: longitude)
                    completion(location)
                }
            }
        }
    }

    // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
    // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770

    func getMemoryUsedAndDeviceTotalInMegabytes() -> (Float, Float) {
        var usedmegabytes: Float = 0
        let totalbytes = Float(ProcessInfo.processInfo.physicalMemory)
        let totalmegabytes = totalbytes / 1024.0 / 1024.0
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            let usedbytes: Float = Float(info.resident_size)
            usedmegabytes = usedbytes / 1024.0 / 1024.0
        }

        return (usedmegabytes, totalmegabytes)
    }

    func getHeightHeaderEmptyData(view: UIView, portraitOffset: CGFloat, landscapeOffset: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        if UIDevice.current.orientation.isPortrait {
            height = (view.frame.height / 2) - (view.safeAreaInsets.top / 2) + portraitOffset
        } else {
            height = (view.frame.height / 2) + landscapeOffset
        }
        return height
    }

    func formatBadgeCount(_ count: Int) -> String {
        if count <= 9999 {
            return "\(count)"
        } else {
            return count.formatted(.number.notation(.compactName).locale(Locale(identifier: "en_US")))
        }
    }
}
