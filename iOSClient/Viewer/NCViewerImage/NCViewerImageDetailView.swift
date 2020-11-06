//
//  NCViewerImageDetailView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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
import MapKit

class NCViewerImageDetailView: UIView {
    
    @IBOutlet weak var mapHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locationButton: UIButton!

    var localFile: tableLocalFile?
    var latitude: Double = 0
    var longitude: Double = 0
    var location: String?
    var date: NSDate?
    var heightMap: CGFloat = 0
    var size: Double = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
    }
    
    func show() {
        isHidden = false
    }
    
    func hide() {
        isHidden = true
    }
    
    func isShow() -> Bool {
        return !isHidden
    }
    
    func hasData() -> Bool {
        if localFile != nil {
            return true
        }
        return false
    }
    
    //MARK: - EXIF
    
    func update(metadata: tableMetadata, heightMap:  CGFloat, textColor: UIColor) {
                    
        self.heightMap = heightMap
        dateLabel.textColor = textColor
        
        if metadata.typeFile == k_metadataTypeFile_image {
            CCUtility.setExif(metadata) { (latitude, longitude, location, date) in
                self.latitude = latitude
                self.longitude = longitude
                self.location = location
                self.date = date as NSDate?
                self.updateContent()
            };
        }
    
        if let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            
            let latitudeString = localFile.exifLatitude
            let longitudeString = localFile.exifLongitude
            self.latitude = Double(localFile.exifLatitude) ?? 0
            self.longitude = Double(localFile.exifLongitude) ?? 0
            self.date = localFile.exifDate
            self.size = localFile.size
            
            if let locationDB = NCManageDatabase.sharedInstance.getLocationFromGeoLatitude(latitudeString, longitude: longitudeString) {
                location = locationDB
            }
           
            self.updateContent()
        }
    }
    
    //MARK: - Map
    
    func updateContent() {
        
        if let date = self.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            let dateString = formatter.string(from: date as Date)
            formatter.dateFormat = "HH:mm"
            let timeString = formatter.string(from: date as Date)
            self.dateLabel.text = dateString + ", " + timeString
        }
        
        if latitude > 0 && longitude > 0 {
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapView.addAnnotation(annotation)
            mapView.setRegion(MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
            locationButton.setTitle(location, for: .normal)
            mapHeightConstraint.constant = self.heightMap
            
        } else {
            
            mapHeightConstraint.constant = 0
            locationButton.setTitle("" , for: .normal)
        }
    }
    
    //MARK: - Action

    @IBAction func touchLocation(_ sender: Any) {
        
        if self.latitude > 0 && self.longitude > 0 {
            
            let latitude: CLLocationDegrees = self.latitude
            let longitude: CLLocationDegrees = self.longitude

            let regionDistance:CLLocationDistance = 10000
            let coordinates = CLLocationCoordinate2DMake(latitude, longitude)
            let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
            let options = [
                MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
                MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
            ]
            let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
            let mapItem = MKMapItem(placemark: placemark)
            mapItem.name = location
            mapItem.openInMaps(launchOptions: options)
        }
    }
}
