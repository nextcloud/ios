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
    var annotation = MKPointAnnotation()
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
    }
    
    func updateExifLocal(metadata: tableMetadata) {
        if metadata.typeFile == k_metadataTypeFile_image {
            CCExifGeo.sharedInstance()?.setExif(metadata)
        }
        
        if let localFile = NCManageDatabase.sharedInstance.getTableLocalFile(predicate: NSPredicate(format: "ocId == %@", metadata.ocId)) {
            
            let latitude = Double(localFile.exifLatitude) ?? 0
            let longitude = Double(localFile.exifLongitude) ?? 0
            
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapView.addAnnotation(annotation)
        }
    }
}
