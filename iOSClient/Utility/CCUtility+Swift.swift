//
//  CCUtility+Swift.swift
//  Nextcloud
//
//  Created by Milen on 27.07.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import 
@objc extension CCUtility {
    func setExif(metadata: tableMetadata, completionHandler: @escaping (Double, Double, String, Date?, String) -> Void) {
        var dateTime: String?
        var latitudeRef: String?
        var longitudeRef: String?
        var stringLatitude = "0"
        var stringLongitude = "0"
        var location = ""
        var latitude = 0.0
        var longitude = 0.0
        var date: Date?
        var fileSize: Int64 = 0
        var pixelY = 0
        var pixelX = 0
        var lensModel = ""

        if metadata.classFile != "image" || !CCUtility.fileProviderStorageExists(metadata) {
            completionHandler(latitude, longitude, location, date, lensModel)
            return
        }

        let url = URL(fileURLWithPath: CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView))

        guard let originalSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            completionHandler(latitude, longitude, location, date, lensModel)
            return
        }

        guard let fileProperties = CGImageSourceCopyProperties(originalSource, nil) as NSDictionary? else {
            completionHandler(latitude, longitude, location, date, lensModel)
            return
        }

        // FILE PROPERTIES
        if let fileSizeNumber = fileProperties[kCGImagePropertyFileSize] as? NSNumber {
            fileSize = fileSizeNumber.int64Value
        }

        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(originalSource, 0, nil) as NSDictionary? else {
            completionHandler(latitude, longitude, location, date, lensModel)
            return
        }

        if let tiff = imageProperties[kCGImagePropertyTIFFDictionary] as? NSDictionary {
            dateTime = tiff[kCGImagePropertyTIFFDateTime] as? String
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            date = dateFormatter.date(from: dateTime ?? "")
        }

        if let gps = imageProperties[kCGImagePropertyGPSDictionary] as? NSDictionary {
            if let latitudeString = gps[kCGImagePropertyGPSLatitude] as? String,
               let latitudeRefString = gps[kCGImagePropertyGPSLatitudeRef] as? String,
               let longitudeString = gps[kCGImagePropertyGPSLongitude] as? String,
               let longitudeRefString = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                latitude = (latitudeString as NSString).doubleValue
                longitude = (longitudeString as NSString).doubleValue

                latitudeRef = latitudeRefString
                longitudeRef = longitudeRefString

                // conversion 4 decimal +N -S
                // The latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator.
                if latitudeRef == "N" {
                    stringLatitude = "+\(String(format: "%.4f", latitude))"
                } else {
                    stringLatitude = "-\(String(format: "%.4f", latitude))"
                    latitude *= -1
                }

                // conversion 4 decimal +E -W
                // The longitude in degrees. Measurements are relative to the zero meridian, with positive values extending east of the meridian
                // and negative values extending west of the meridian.
                if longitudeRef == "E" {
                    stringLongitude = "+\(String(format: "%.4f", longitude))"
                } else {
                    stringLongitude = "-\(String(format: "%.4f", longitude))"
                    longitude *= -1
                }

                if latitude == 0 || longitude == 0 {
                    stringLatitude = "0"
                    stringLongitude = "0"
                }
            }
        }

        // Write data EXIF in DB
        if imageProperties[kCGImagePropertyTIFFDictionary] != nil || imageProperties[kCGImagePropertyGPSDictionary] != nil {
            NCManageDatabase.shared.setLocalFile(ocId: metadata.ocId, exifDate: date as NSDate?, exifLatitude: stringLatitude, exifLongitude: stringLongitude, exifLensModel: lensModel)

            if Double(stringLatitude) != 0 || Double(stringLongitude) != 0 {
                // If exists already geocoder data in TableGPS exit
                location = NCManageDatabase.shared.getLocationFromGeoLatitude(stringLatitude, longitude: stringLongitude) ?? ""

                if !location.isEmpty {
                    completionHandler(latitude, longitude, location, date, lensModel)
                    return
                }

                let geocoder = CLGeocoder()
                let llocation = CLLocation(latitude: latitude, longitude: longitude)

                geocoder.reverseGeocodeLocation(llocation) { placemarks, error in
                    if error == nil, let placemark = placemarks?.last {
                        var thoroughfare = ""
                        var postalCode = ""
                        var locality = ""
                        var administrativeArea = ""
                        var country = ""

                        if let placemarkThoroughfare = placemark.thoroughfare {
                            thoroughfare = placemarkThoroughfare
                        }
                        if let placemarkPostalCode = placemark.postalCode {
                            postalCode = placemarkPostalCode
                        }
                        if let placemarkLocality = placemark.locality {
                            locality = placemarkLocality
                        }
                        if let placemarkAdministrativeArea = placemark.administrativeArea {
                            administrativeArea = placemarkAdministrativeArea
                        }
                        if let placemarkCountry = placemark.country {
                            country = placemarkCountry
                        }

                        location = "\(thoroughfare) \(postalCode) \(locality) \(administrativeArea) \(country)"
                        location = location.trimmingCharacters(in: .whitespaces)

                        // GPS
                        if !location.isEmpty {
                            NCManageDatabase.shared.addGeocoderLocation(location, placemarkAdministrativeArea: administrativeArea, placemarkCountry: country, placemarkLocality: locality, placemarkPostalCode: postalCode, placemarkThoroughfare: thoroughfare, latitude: stringLatitude, longitude: stringLongitude)
                        }

                        completionHandler(latitude, longitude, location, date, lensModel)
                    }
                }
            } else {
                completionHandler(latitude, longitude, location, date, lensModel)
            }
        } else {
            completionHandler(latitude, longitude, location, date, lensModel)
        }
    }

}
