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
    private weak var presentingViewController: UIViewController?
    private let explanationShownKey = "locationExplanationShown"

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.activityType = .otherNavigation
    }

    func start(from viewController: UIViewController) {
        self.presentingViewController = viewController

        let status = locationManager.authorizationStatus

        if status == .notDetermined {
            if !UserDefaults.standard.bool(forKey: explanationShownKey) {
                presentInitialExplanation(from: viewController)
            } else {
                locationManager.requestAlwaysAuthorization()
            }
        } else if status != .authorizedAlways {
            presentSettingsAlert(from: viewController)
        } else {
            locationManager.startMonitoringSignificantLocationChanges()
            NextcloudKit.shared.nkCommonInstance.writeLog("Location monitoring started")
        }
    }

    func stop() {
        locationManager.stopMonitoringSignificantLocationChanges()
        NextcloudKit.shared.nkCommonInstance.writeLog("Location monitoring stopped")
    }

    func checkLocationServiceIsActive(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard CLLocationManager.locationServicesEnabled() else {
                return completion(false)
            }
            let status = self.locationManager.authorizationStatus
            let isActive = (status == .authorizedAlways)

            completion(isActive)
        }
    }

    private func presentInitialExplanation(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: NSLocalizedString("_background_location_access_title_", comment: ""),
            message: NSLocalizedString("_background_location_access_message_", comment: ""),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: NSLocalizedString("_continue_", comment: ""), style: .default) { _ in
            UserDefaults.standard.set(true, forKey: self.explanationShownKey)
            self.locationManager.requestAlwaysAuthorization()
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))

        viewController.present(alert, animated: true)
    }

    private func presentSettingsAlert(from viewController: UIViewController) {
        let alert = UIAlertController(
            title: NSLocalizedString("_enable_background_location_title_", comment: ""),
            message: NSLocalizedString("_enable_background_location_message_", comment: ""),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: NSLocalizedString("_open_settings_", comment: ""), style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel))

        viewController.present(alert, animated: true)
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

        Task.detached {
            let numTransfers = await self.appDelegate.autoUpload()
            NextcloudKit.shared.nkCommonInstance.writeLog("Triggered upload completed with \(numTransfers) transfers")
            self.isProcessing = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NextcloudKit.shared.nkCommonInstance.writeLog("Location error: \(error.localizedDescription)")
    }
}
