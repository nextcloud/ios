//
//  NCViewerImageDetailView.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 31/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation
import MapKit

class NCViewerImageDetailView: UIView {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locationButton: UIButton!

    var annotation = MKPointAnnotation()
    var latitude: Double = 0
    var longitude: Double = 0
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
    }
    
    func updateExifLocal(metadata: tableMetadata) {
        if metadata.typeFile == k_metadataTypeFile_image {
            CCExifGeo.sharedInstance()?.setExif(metadata)
        }
        
        if let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            
            latitude = Double(localFile.exifLatitude) ?? 0
            longitude = Double(localFile.exifLongitude) ?? 0
            
            if latitude > 0 && longitude > 0 {
            
                annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                mapView.addAnnotation(annotation)
                mapView.setRegion(MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
                
                if let location = NCManageDatabase.sharedInstance.getLocationFromGeoLatitude(localFile.exifLatitude, longitude: localFile.exifLongitude) {
                    locationButton.setTitle(location, for: .normal)
                }
            }
        }
    }
}
