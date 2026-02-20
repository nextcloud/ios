// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

public struct ExifData {
    var colorModel: String?
    var width: Int?
    var height: Int?
    var dpiWidth: Int?
    var dpiHeight: Int?
    var depth: Int?
    var orientation: Int?
    var apertureValue: Double?
    var exposureValue: Int?
    var shutterSpeedApex: Double?
    var iso: Int?
    var lensLength: Int?
    var brightnessValue: String?
    var dateTimeDigitized: String?
    var dateTimeOriginal: String?
    var offsetTime: String?
    var offsetTimeDigitized: String?
    var offsetTimeOriginal: String?
    var make: String?
    var model: String?
    var software: String?
    var tileLength: Double?
    var tileWidth: Double?
    var xResolution: Double?
    var yResolution: Double?
    var altitude: String?
    var destBearing: String?
    var hPositioningError: String?
    var imgDirection: String?
    var latitude: Double?
    var longitude: Double?
    var speed: Double?
    var location: String?
    var lensModel: String?
    var date: Date?
}

extension NCUtility {
    func getExif(metadata: tableMetadata, completion: @escaping (ExifData) -> Void) {
        var data = ExifData()

        writeExifFromMetadata(metadata: metadata, data: &data)

        if let latitude = data.latitude, let longitude = data.longitude {
            getLocation(latitude: latitude, longitude: longitude) { location in
                data.location = location
                completion(data)
            }
        }

        if metadata.classFile != "image" || !utilityFileSystem.fileProviderStorageExists(metadata) {
            print("Storage exists or file is not an image")
        }

        let url = URL(fileURLWithPath: utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId,
                                                                                         fileName: metadata.fileNameView,
                                                                                         userId: metadata.userId,
                                                                                         urlBase: metadata.urlBase))

        guard let originalSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as NSDictionary? else {
            print("Could not get image properties")
            completion(data)
            return
        }

        data.colorModel = imageProperties[kCGImagePropertyColorModel] as? String
        data.height = imageProperties[kCGImagePropertyPixelWidth] as? Int
        data.width = imageProperties[kCGImagePropertyPixelHeight] as? Int
        data.dpiWidth = imageProperties[kCGImagePropertyDPIWidth] as? Int
        data.dpiHeight = imageProperties[kCGImagePropertyDPIHeight] as? Int
        data.depth = imageProperties[kCGImagePropertyDepth] as? Int
        data.orientation = imageProperties[kCGImagePropertyOrientation] as? Int

        if let tiffData = imageProperties[kCGImagePropertyTIFFDictionary] as? NSDictionary {
            data.make = tiffData[kCGImagePropertyTIFFMake] as? String
            data.model = tiffData[kCGImagePropertyTIFFModel] as? String
            data.software = tiffData[kCGImagePropertyTIFFSoftware] as? String
            data.tileLength = tiffData[kCGImagePropertyTIFFTileLength] as? Double
            data.tileWidth = tiffData[kCGImagePropertyTIFFTileWidth] as? Double
            data.xResolution = tiffData[kCGImagePropertyTIFFXResolution] as? Double
            data.yResolution = tiffData[kCGImagePropertyTIFFYResolution] as? Double

            let dateTime = tiffData[kCGImagePropertyTIFFDateTime] as? String
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            data.date = dateFormatter.date(from: dateTime ?? "")
        }

        if let exifData = imageProperties[kCGImagePropertyExifDictionary] as? NSDictionary {
            data.apertureValue = exifData[kCGImagePropertyExifFNumber] as? Double
            data.exposureValue = exifData[kCGImagePropertyExifExposureBiasValue] as? Int
            data.shutterSpeedApex = exifData[kCGImagePropertyExifShutterSpeedValue] as? Double
            data.iso = (exifData[kCGImagePropertyExifISOSpeedRatings] as? [Int])?[0]
            data.lensLength = exifData[kCGImagePropertyExifFocalLenIn35mmFilm] as? Int
            data.brightnessValue = exifData[kCGImagePropertyExifBrightnessValue] as? String
            data.dateTimeDigitized = exifData[kCGImagePropertyExifDateTimeDigitized] as? String
            data.dateTimeOriginal = exifData[kCGImagePropertyExifDateTimeOriginal] as? String
            data.offsetTime = exifData[kCGImagePropertyExifOffsetTime] as? String
            data.offsetTimeDigitized = exifData[kCGImagePropertyExifOffsetTimeDigitized] as? String
            data.offsetTimeOriginal = exifData[kCGImagePropertyExifOffsetTimeOriginal] as? String
            data.lensModel = exifData[kCGImagePropertyExifLensModel] as? String
        }

        if let gpsData = imageProperties[kCGImagePropertyGPSDictionary] as? NSDictionary {
            data.altitude = gpsData[kCGImagePropertyGPSAltitude] as? String
            data.destBearing = gpsData[kCGImagePropertyGPSDestBearing] as? String
            data.hPositioningError = gpsData[kCGImagePropertyGPSHPositioningError] as? String
            data.imgDirection = gpsData[kCGImagePropertyGPSImgDirection] as? String
            data.latitude = gpsData[kCGImagePropertyGPSLatitude] as? Double
            if gpsData[kCGImagePropertyGPSLatitudeRef] as? String == "S" {
                data.latitude! *= -1
            }
            data.longitude = gpsData[kCGImagePropertyGPSLongitude] as? Double
            if gpsData[kCGImagePropertyGPSLongitudeRef] as? String == "W" {
                data.longitude! *= -1
            }
            data.speed = gpsData[kCGImagePropertyGPSSpeed] as? Double
        }

        writeExifFromMetadata(metadata: metadata, data: &data)

        if let latitude = data.latitude, let longitude = data.longitude {
            getLocation(latitude: latitude, longitude: longitude) { location in
                data.location = location
                completion(data)
            }
        }

        completion(data)
    }

    /**
     Since non-downloaded images are usually thumbnails, the server sends some exif metadata of the real image. This function writes that data to the local exif object, if that data doesn't exist already.
     */
    private func writeExifFromMetadata(metadata: tableMetadata, data: inout ExifData) {
        if metadata.latitude != 0, metadata.longitude != 0 {
            if data.latitude == nil { data.latitude = metadata.latitude }
            if data.longitude == nil { data.longitude = metadata.longitude }
        }

        if metadata.height != 0, metadata.width != 0 {
            if data.height == nil { data.height = metadata.height }
            if data.width == nil { data.width = metadata.width }
        }
    }
}
