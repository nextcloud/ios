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
    @IBOutlet weak var mapContainer: UIView!
    @IBOutlet weak var outerMapContainer: UIView!
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var noDateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var modelLabel: UILabel!
    @IBOutlet weak var deviceContainer: UIView!
    @IBOutlet weak var outerContainer: UIView!
    @IBOutlet weak var lensLabel: UILabel!
    @IBOutlet weak var megaPixelLabel: UILabel!
    @IBOutlet weak var megaPixelLabelDivider: UILabel!
    @IBOutlet weak var resolutionLabel: UILabel!
    @IBOutlet weak var resolutionLabelDivider: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var extensionLabel: UILabel!
    @IBOutlet weak var livePhotoImageView: UIImageView!
    @IBOutlet weak var isoLabel: UILabel!
    @IBOutlet weak var lensSizeLabel: UILabel!
    @IBOutlet weak var exposureValueLabel: UILabel!
    @IBOutlet weak var apertureLabel: UILabel!
    @IBOutlet weak var shutterSpeedLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var downloadImageButton: UIButton!
    @IBOutlet weak var downloadImageLabel: UILabel!
    @IBOutlet weak var downloadImageButtonContainer: UIStackView!
    @IBOutlet weak var dateContainer: UIView!
    @IBOutlet weak var lensInfoStackViewLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var lensInfoStackViewTrailingConstraint: NSLayoutConstraint!
    @IBOutlet weak var lensInfoLeadingFakePadding: UILabel!
    @IBOutlet weak var lensInfoTrailingFakePadding: UILabel!

    private var metadata: tableMetadata?
    private var mapView: MKMapView?
    private var ncplayer: NCPlayer?
    weak var delegate: NCViewerMediaDetailViewDelegate?
    let utilityFileSystem = NCUtilityFileSystem()

    private var exif: ExifData?

    var isShown: Bool {
        return !self.isHidden
    }

    deinit {
        print("deinit NCViewerMediaDetailView")

        self.mapView?.removeFromSuperview()
        self.mapView = nil
    }

    func show(metadata: tableMetadata,
              image: UIImage?,
              textColor: UIColor?,
              exif: ExifData,
              ncplayer: NCPlayer?,
              delegate: NCViewerMediaDetailViewDelegate?) {

        self.metadata = metadata
        self.exif = exif
        self.ncplayer = ncplayer
        self.delegate = delegate

        outerMapContainer.isHidden = true
        downloadImageButtonContainer.isHidden = true

        if let latitude = exif.latitude, let longitude = exif.longitude, NCNetworking.shared.isOnline {
            // We hide the map view on phones in landscape (aka compact height), since there is too little space to fit all of it.
            mapContainer.isHidden = traitCollection.verticalSizeClass == .compact

            outerMapContainer.isHidden = false
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            let region = MKCoordinateRegion(center: annotation.coordinate, latitudinalMeters: 500, longitudinalMeters: 500)

            if mapView == nil, mapView?.region.center.latitude != latitude, mapView?.region.center.longitude != longitude {
                let mapView = MKMapView()
                self.mapView = mapView
                mapContainer.subviews.forEach { $0.removeFromSuperview() }
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

                mapView.setRegion(region, animated: false)
            }
        }

        if let make = exif.make, let model = exif.model, let lensModel = exif.lensModel {
            modelLabel.text = "\(make) \(model)"
            lensLabel.text = lensModel
                .replacingOccurrences(of: make, with: "")
                .replacingOccurrences(of: model, with: "")
                .replacingOccurrences(of: "f/", with: "ƒ").trimmingCharacters(in: .whitespacesAndNewlines).firstUppercased
        } else {
            modelLabel.text = NSLocalizedString("_no_camera_information_", comment: "")
            lensLabel.text = NSLocalizedString("_no_lens_information_", comment: "")
        }

        nameLabel.text = (metadata.fileNameView as NSString).deletingPathExtension
        sizeLabel.text = utilityFileSystem.transformedSize(metadata.size)

        if let shutterSpeedApex = exif.shutterSpeedApex {
            prepareLensInfoViewsForData()
            shutterSpeedLabel.text = "1/\(Int(pow(2, shutterSpeedApex))) s"
        }

        if let iso = exif.iso {
            prepareLensInfoViewsForData()
            isoLabel.text = "ISO \(iso)"
        }

        if let apertureValue = exif.apertureValue {
            apertureLabel.text = "ƒ\(apertureValue)"
        }

        if let exposureValue = exif.exposureValue {
            exposureValueLabel.text = "\(exposureValue) ev"
        }

        if let lensLength = exif.lensLength {
            lensSizeLabel.text = "\(lensLength) mm"
        }

        if let date = exif.date {
            dateContainer.isHidden = false
            noDateLabel.isHidden = true

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
            noDateLabel.text = NSLocalizedString("_no_date_information_", comment: "")
        }

        if let height = exif.height, let width = exif.width {
            megaPixelLabel.isHidden = false
            megaPixelLabelDivider.isHidden = false
            resolutionLabel.isHidden = false
            resolutionLabelDivider.isHidden = false

            resolutionLabel.text = "\(width) x \(height)"

            let megaPixels: Double = Double(width * height) / 1000000
            megaPixelLabel.text = megaPixels < 1 ? String(format: "%.1f MP", megaPixels) : "\(Int(megaPixels)) MP"
        }

        extensionLabel.text = metadata.fileExtension.uppercased()

        if exif.location?.isEmpty == false {
            locationLabel.text = exif.location
        }

        if metadata.isLivePhoto {
            livePhotoImageView.isHidden = false
        }

        if metadata.isImage && !utilityFileSystem.fileProviderStorageExists(metadata) && metadata.session.isEmpty {
            downloadImageButton.setTitle(NSLocalizedString("_try_download_full_resolution_", comment: ""), for: .normal)
            downloadImageLabel.text = NSLocalizedString("_full_resolution_image_info_", comment: "")
            downloadImageButtonContainer.isHidden = false
        }

        self.isHidden = false
        layoutIfNeeded()
    }

    func hide() {
        self.isHidden = true
    }

    private func prepareLensInfoViewsForData() {
        lensInfoLeadingFakePadding.isHidden = true
        lensInfoTrailingFakePadding.isHidden = true
        lensInfoStackViewLeadingConstraint.constant = 5
        lensInfoStackViewTrailingConstraint.constant = 5
    }

    // MARK: - Action

    @IBAction func touchLocation(_ sender: Any) {
        guard let latitude = exif?.latitude, let longitude = exif?.longitude else { return }

        let latitudeDeg: CLLocationDegrees = latitude
        let longitudeDeg: CLLocationDegrees = longitude

        let coordinates = CLLocationCoordinate2DMake(latitudeDeg, longitudeDeg)
        let placemark = MKPlacemark(coordinate: coordinates, addressDictionary: nil)
        let mapItem = MKMapItem(placemark: placemark)

        if let location = exif?.location {
            mapItem.name = location
        }

        mapItem.openInMaps()
    }

    @IBAction func touchDownload(_ sender: Any) {
        delegate?.downloadFullResolution()
    }
}
