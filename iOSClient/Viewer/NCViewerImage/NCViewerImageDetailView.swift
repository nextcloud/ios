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
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
    }
    
    func updateExifLocal(metadata: tableMetadata) {
        if metadata.typeFile == k_metadataTypeFile_image {
            let metadata = tableMetadata.init(value: metadata)
            CCExifGeo.sharedInstance()?.setExifLocalTable(metadata)
        }
    }
}
