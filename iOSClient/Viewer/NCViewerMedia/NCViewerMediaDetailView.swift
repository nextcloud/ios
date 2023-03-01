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
import NextcloudKit

typealias NCImageMetadata = (latitude: Double, longitude: Double, location: String?, date: Date?, lensModel: String?)

public protocol NCViewerMediaDetailViewDelegate: AnyObject {
    func downloadFullResolution()
}

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
    @IBOutlet weak var messageButton: UIButton!
    @IBOutlet weak var mapContainer: UIView!
    @IBOutlet weak var locationButton: UIButton!

    var latitude: Double = 0
    var longitude: Double = 0
    var location: String?
    var date: Date?
    var lensModel: String?
    var metadata: tableMetadata?
    var mapView: MKMapView?
    var ncplayer: NCPlayer?
    weak var delegate: NCViewerMediaDetailViewDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        separator.backgroundColor = .separator
        sizeLabel.text = ""
        sizeValue.text = ""
        dateLabel.text = ""
        dateValue.text = ""
        dimLabel.text = ""
        dimValue.text = ""
        lensModelLabel.text = ""
        lensModelValue.text = ""
        messageButton.setTitle("", for: .normal)
        locationButton.setTitle("", for: .normal)
    }

    deinit {
        print("deinit NCViewerMediaDetailView")

        self.mapView?.removeFromSuperview()
        self.mapView = nil
    }

    func show(metadata: tableMetadata,
              image: UIImage?,
              textColor: UIColor?,
              mediaMetadata: NCImageMetadata,
              ncplayer: NCPlayer?,
              delegate: NCViewerMediaDetailViewDelegate?) {

        self.metadata = metadata
        self.latitude = mediaMetadata.latitude
        self.longitude = mediaMetadata.longitude
        self.location = mediaMetadata.location
        self.date = mediaMetadata.date
        self.lensModel = mediaMetadata.lensModel
        self.ncplayer = ncplayer
        self.delegate = delegate

        if mapView == nil && (latitude != -1 && latitude != 0 && longitude != -1 && longitude != 0) {

            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let mapView = MKMapView()
            self.mapView = mapView
            self.mapContainer.addSubview(mapView)

            mapView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mapView.topAnchor.constraint(equalTo: self.mapContainer.topAnchor),
                mapView.bottomAnchor.constraint(equalTo: self.mapContainer.bottomAnchor),
                mapView.leadingAnchor.constraint(equalTo: self.mapContainer.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: self.mapContainer.trailingAnchor)
            ])

            mapView.layer.cornerRadius = 6
            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = false
            mapView.isUserInteractionEnabled = false
            mapView.addAnnotation(annotation)
            mapView.setRegion(MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
        }

        // Size
        sizeLabel.text = NSLocalizedString("_size_", comment: "")
        sizeValue.text = CCUtility.transformedSize(metadata.size)
        sizeValue.textColor = textColor

        // Date
        if let date = date {
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
        dateValue.textColor = textColor

        // Dimension / Duration
        if metadata.classFile == NKCommon.TypeClassFile.image.rawValue {
            if let image = image {
                dimLabel.text = NSLocalizedString("_resolution_", comment: "")
                dimValue.text = "\(Int(image.size.width)) x \(Int(image.size.height))"
            }
        } else if metadata.classFile == NKCommon.TypeClassFile.video.rawValue || metadata.classFile == NKCommon.TypeClassFile.audio.rawValue {
            if let durationTime = NCManageDatabase.shared.getVideoDurationTime(metadata: metadata) {
                self.dimLabel.text = NSLocalizedString("_duration_", comment: "")
                self.dimValue.text = NCUtility.shared.stringFromTime(durationTime)
            }
        }
        dimValue.textColor = textColor

        // Model
        if let lensModel = lensModel {
            lensModelLabel.text = NSLocalizedString("_model_", comment: "")
            lensModelValue.text = lensModel
            lensModelValue.textColor = textColor
        }

        // Message
        if metadata.classFile == NKCommon.TypeClassFile.image.rawValue && !CCUtility.fileProviderStorageExists(metadata) && metadata.session.isEmpty {
            messageButton.setTitle(NSLocalizedString("_try_download_full_resolution_", comment: ""), for: .normal)
            messageButton.isHidden = false
        } else {
            messageButton.setTitle("", for: .normal)
            messageButton.isHidden = true
        }

        // Location
        if let location = location {
            locationButton.setTitle(location, for: .normal)
            locationButton.isHidden = false
        } else {
            locationButton.setTitle("", for: .normal)
            locationButton.isHidden = true
        }

        self.isHidden = false
    }

    func hide() {
        self.isHidden = true
    }

    func isShow() -> Bool {
        return !self.isHidden
    }

    // MARK: - Action

    @IBAction func touchLocation(_ sender: Any) {

        guard latitude != -1, latitude != 0, longitude != -1, longitude != 0 else { return }

        let latitude: CLLocationDegrees = self.latitude
        let longitude: CLLocationDegrees = self.longitude

        let regionDistance: CLLocationDistance = 10000
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

    @IBAction func touchFavorite(_ sender: Any) {

    }

    @IBAction func touchMessage(_ sender: Any) {
        delegate?.downloadFullResolution()
    }
}
