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

public protocol NCViewerMediaDetailViewDelegate: AnyObject {
    func downloadFullResolution()
}

class NCViewerMediaDetailView: UIView {

    @IBOutlet weak var separator: UIView!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var dateValue: UILabel!
    @IBOutlet weak var dimLabel: UILabel!
    @IBOutlet weak var dimValue: UILabel!
    @IBOutlet weak var lensModelLabel: UILabel!
    @IBOutlet weak var lensModelValue: UILabel!
    @IBOutlet weak var messageButton: UIButton!
    @IBOutlet weak var mapContainer: UIView!
    @IBOutlet weak var locationButton: UIButton!

    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var deviceContainer: UIView!
    @IBOutlet weak var outerContainer: UIView!
    @IBOutlet weak var lensLabel: UILabel!
    @IBOutlet weak var megaPixelLabel: UILabel!
    @IBOutlet weak var resolutionLabel: UILabel!

    var metadata: tableMetadata?
    var mapView: MKMapView?
    var ncplayer: NCPlayer?
    weak var delegate: NCViewerMediaDetailViewDelegate?

    var exif: NCUtility.ExifData?

    override func awakeFromNib() {
        super.awakeFromNib()

        separator.backgroundColor = .separator
        sizeLabel.text = ""
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
              exif: NCUtility.ExifData,
              ncplayer: NCPlayer?,
              delegate: NCViewerMediaDetailViewDelegate?) {

        self.metadata = metadata
        self.exif = exif
        self.ncplayer = ncplayer
        self.delegate = delegate

        if mapView == nil, let latitude = exif.latitude, let longitude = exif.longitude {

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

            mapView.isZoomEnabled = true
            mapView.isScrollEnabled = false
            mapView.isUserInteractionEnabled = false
            mapView.addAnnotation(annotation)
            mapView.setRegion(MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500), animated: false)
        }

        if let make = exif.make, let model = exif.model, let lensModel = exif.lensModel {
            modelLabel.text = "\(make) \(model)"
            lensLabel.text = lensModel.replacingOccurrences(of: make, with: "").replacingOccurrences(of: model, with: "").trimmingCharacters(in: .whitespacesAndNewlines).firstUppercased
        }

        nameLabel.text = metadata.fileNameView

        sizeLabel.text = CCUtility.transformedSize(metadata.size)

        if let date = exif.date {
            let formatter = DateFormatter()

            formatter.dateFormat = "EEEE"
            let dayString = formatter.string(from: date as Date)
            dayLabel.text = dayString

            formatter.dateFormat = "d MMM yyyy"
            let dateString = formatter.string(from: date as Date)
            dateLabel.text = dateString

            formatter.dateFormat = "HH:mm"
            let timeString = formatter.string(from: date as Date)
            timeLabel.text = timeString
        } else {
            dayLabel.text = NSLocalizedString("no_day_", comment: "")
            dateLabel.text = NSLocalizedString("no_date_", comment: "")
            timeLabel.text = NSLocalizedString("no_time_", comment: "")
        }

        dateValue.textColor = textColor

        if let image = image {
            resolutionLabel.text = "\(Int(image.size.width)) x \(Int(image.size.height))"
            megaPixelLabel.text = "\(Int(floor(image.size.width * image.size.height) / 1000000)) MP"
        }

        if metadata.isImage && !CCUtility.fileProviderStorageExists(metadata) && metadata.session.isEmpty {
            messageButton.setTitle(NSLocalizedString("_try_download_full_resolution_", comment: ""), for: .normal)
            messageButton.isHidden = false
        } else {
            messageButton.setTitle("", for: .normal)
            messageButton.isHidden = true
        }

        if let location = exif.location {
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

    func isShown() -> Bool {
        return !self.isHidden
    }

    // MARK: - Action

    @IBAction func touchLocation(_ sender: Any) {
        guard let latitude = exif?.latitude, let longitude = exif?.longitude else { return }

        let latitudeDeg: CLLocationDegrees = latitude
        let longitudeDeg: CLLocationDegrees = longitude

        let regionDistance: CLLocationDistance = 10000
        let coordinates = CLLocationCoordinate2DMake(latitudeDeg, longitudeDeg)
        let regionSpan = MKCoordinateRegion(center: coordinates, latitudinalMeters: regionDistance, longitudinalMeters: regionDistance)
        let options = [
            MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center),
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span)
        ]
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)

        if let location = exif?.location {
            mapItem.name = location
        }

        mapItem.openInMaps(launchOptions: options)
    }

    @IBAction func touchMessage(_ sender: Any) {
        delegate?.downloadFullResolution()
    }
}
