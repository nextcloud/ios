//
//  NCViewerMediaDetailView.swift
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

import UIKit
import MapKit
import NCCommunication

class NCViewerMediaDetailView: UIView {
    
    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var sizeValue: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var dateValue: UILabel!
    @IBOutlet weak var dimLabel: UILabel!
    @IBOutlet weak var dimValue: UILabel!
    @IBOutlet weak var lensModelLabel: UILabel!
    @IBOutlet weak var lensModelValue: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var mapHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var locationButton: UIButton!

    var metadata: tableMetadata?
    
    var latitude: Double = 0
    var longitude: Double = 0
    var location: String?
    var date: NSDate?
    var lensModel: String?
    var heightMap: CGFloat = 0
    var size: Int64 = 0
    var image: UIImage?
    
    override func awakeFromNib() {
        super.awakeFromNib()
           
        mapView.layer.cornerRadius = 6
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = false
        mapView.isUserInteractionEnabled = false
                
        sizeLabel.text = ""
        sizeValue.text = ""
        dateLabel.text = ""
        dateValue.text = ""
        dimLabel.text = ""
        dimValue.text = ""
        lensModelLabel.text = ""
        lensModelValue.text = ""
        messageLabel.text = ""
        messageLabel.textColor = NCBrandColor.shared.brand
        locationButton.setTitle("" , for: .normal)
    }
    
    deinit {
        print("deinit NCViewerMediaDetailView")
    }
    
    func textColor(_ textColor: UIColor?) {
        sizeValue.textColor = textColor
        dateValue.textColor = textColor
        dimValue.textColor = textColor
        lensModelValue.textColor = textColor
        separator.backgroundColor = NCBrandColor.shared.separator
    }
    
    func show(textColor: UIColor?) {
        self.textColor(textColor)
        isHidden = false
    }
    
    func hide() {
        isHidden = true
    }
    
    func isShow() -> Bool {
        return !isHidden
    }
    
    //MARK: - EXIF
    
    func update(metadata: tableMetadata, image: UIImage?, heightMap:  CGFloat) {
                    
        self.metadata = metadata
        self.heightMap = heightMap
        self.image = image
        self.size = metadata.size
        
        if metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
            CCUtility.setExif(metadata) { (latitude, longitude, location, date, lensModel) in
                
                self.latitude = latitude
                self.longitude = longitude
                self.location = location
                self.date = date as NSDate?
                self.lensModel = lensModel
                
                self.updateContent()
            };
        } else {
            self.updateContent()
        }
    }
    
    //MARK: - Map
    
    func updateContent() {
        
        // Size
        sizeLabel.text = NSLocalizedString("_size_", comment: "")
        sizeValue.text = CCUtility.transformedSize(self.size)
        
        // Date
        if let date = self.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            let dateString = formatter.string(from: date as Date)
            
            dateLabel.text = NSLocalizedString("_date_", comment: "")
            dateValue.text = dateString
        } else {
            dateLabel.text = NSLocalizedString("_date_", comment: "")
            dateValue.text = NSLocalizedString("_not_available_", comment: "")
        }
        
        // Dimension / Duration
        if metadata?.classFile == NCCommunicationCommon.typeClassFile.image.rawValue {
            if let image = self.image {
                dimLabel.text = NSLocalizedString("_resolution_", comment: "")
                dimValue.text = "\(Int(image.size.width)) x \(Int(image.size.height))"
            }
        } else if metadata?.classFile == NCCommunicationCommon.typeClassFile.video.rawValue || metadata?.classFile == NCCommunicationCommon.typeClassFile.audio.rawValue  {
            if let durationTime = NCManageDatabase.shared.getVideoDurationTime(metadata: metadata) {
                self.dimLabel.text = NSLocalizedString("_duration_", comment: "")
                self.dimValue.text = NCUtility.shared.stringFromTime(durationTime)
            }
        }
        
        // Model
        if let lensModel = self.lensModel {
            lensModelLabel.text = NSLocalizedString("_model_", comment: "")
            lensModelValue.text = lensModel
        }
        
        // Message
        if let metadata = self.metadata, metadata.classFile == NCCommunicationCommon.typeClassFile.image.rawValue && !CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) && metadata.session == "" {
            messageLabel.text = NSLocalizedString("_try_download_full_resolution_", comment: "")
        } else {
            messageLabel.text = ""
        }
        
        // Map
        if latitude != -1 && latitude != 0 && longitude != -1 && longitude != 0 {
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapView.addAnnotation(annotation)
            mapView.setRegion(MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
            locationButton.setTitle(location, for: .normal)
            mapHeightConstraint.constant = self.heightMap
            
        } else {
            
            mapHeightConstraint.constant = 0
        }
    }
    
    //MARK: - Action

    @IBAction func touchLocation(_ sender: Any) {
        
        if latitude != -1 && latitude != 0 && longitude != -1 && longitude != 0 {
            
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
    
    @IBAction func touchFavorite(_ sender: Any) {
        
    }
    
    //MARK: -
    func secondsToHoursMinutesSeconds (seconds : Int) -> (Int, Int, Int) {
      return (seconds / 3600, (seconds % 3600) / 60, (seconds % 3600) % 60)
    }
}
