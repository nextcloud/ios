//
//  NCBackgroundLocationUploadManager.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 06/06/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import CoreLocation
import NextcloudKit

class NCBackgroundLocationUploadManager: NSObject, CLLocationManagerDelegate {
    static let shared = NCBackgroundLocationUploadManager()

    private let locationManager = CLLocationManager()
    private var isProcessing = false
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .otherNavigation
    }

    func start() {
        locationManager.requestAlwaysAuthorization()
        locationManager.startMonitoringSignificantLocationChanges()
        NextcloudKit.shared.nkCommonInstance.writeLog("Location monitoring started")
    }

    func stop() {
        locationManager.stopMonitoringSignificantLocationChanges()
        NextcloudKit.shared.nkCommonInstance.writeLog("Location monitoring stopped")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isProcessing else {
            NextcloudKit.shared.nkCommonInstance.writeLog("Upload in progress, skipping location trigger")
            return
        }

        isProcessing = true
        let location = locations.last
        let log = "Triggered by location change: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)"
        NextcloudKit.shared.nkCommonInstance.writeLog(log)

        Task {
            let numTransfers = await appDelegate.autoUpload()
            NextcloudKit.shared.nkCommonInstance.writeLog("Triggered upload completed with \(numTransfers) transfers")
            isProcessing = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NextcloudKit.shared.nkCommonInstance.writeLog("Location error: \(error.localizedDescription)")
    }
}
