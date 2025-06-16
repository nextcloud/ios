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

    private let global = NCGlobal.shared
    private let database = NCManageDatabase.shared
    private let locationManager = CLLocationManager()
    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private weak var presentingViewController: UIViewController?
    private let explanationShownKey = "locationExplanationShown"

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func start(from viewController: UIViewController?) {
        self.presentingViewController = viewController

        let status = locationManager.authorizationStatus

        if status == .notDetermined, let viewController {
            if !UserDefaults.standard.bool(forKey: explanationShownKey) {
                presentInitialExplanation(from: viewController)
            } else {
                locationManager.requestAlwaysAuthorization()
            }
        } else if status != .authorizedAlways, let viewController {
            presentSettingsAlert(from: viewController)
        } else {
            locationManager.startMonitoringSignificantLocationChanges()
            nkLog(start: "Location monitoring started")
        }
    }

    func stop() {
        locationManager.stopMonitoringSignificantLocationChanges()
        nkLog(stop: "Location monitoring stopped")
    }

    func checkLocationAuthorizationStatus(completion: @escaping (Bool) -> Void) {
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
        guard isAppInBackground else {
            return
        }

        isAppSuspending = false // now you can read/write in Realm

        let location = locations.last
        nkLog(tag: self.global.logTagLocation, emoji: .start, message: "Triggered by location change: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")

        Task.detached {
            if let tblAccount = await self.database.getActiveTableAccountAsync(),
               await !self.appDelegate.isBackgroundTask {
                // start the BackgroundTask
                await MainActor.run {
                    self.appDelegate.isBackgroundTask = true
                }

                let numTransfers = await self.appDelegate.backgroundSync(tblAccount: tblAccount)
                nkLog(tag: self.global.logTagLocation, emoji: .success, message: "Triggered by location completed with \(numTransfers) transfers")

                // end the BackgroundTask
                await MainActor.run {
                    self.appDelegate.isBackgroundTask = false
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        nkLog(error: "Location error: \(error.localizedDescription)")
    }
}
