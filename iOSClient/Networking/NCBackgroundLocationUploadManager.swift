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
    private weak var presentingViewController: UIViewController?
    private let explanationShownKey = "locationExplanationShown"
    private var continuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        // let status = locationManager.authorizationStatus
        locationManager.startMonitoringSignificantLocationChanges()
    }

    /// Requests `.authorizedAlways` location permission asynchronously.
    /// - Parameter viewController: A view controller to present UI if needed.
    /// - Returns: `true` if `.authorizedAlways` permission is granted, otherwise `false`.
    @MainActor
    func requestAuthorizationAlwaysAsync(from viewController: UIViewController?) async -> Bool {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedAlways:
            // Permission already granted
            return true

        case .notDetermined:
            // Show explanation view if needed before requesting permission
            if let viewController, !UserDefaults.standard.bool(forKey: "locationExplanationShown") {
                presentInitialExplanation(from: viewController)
                return false
            }

            return await withCheckedContinuation { (continuation: CheckedContinuation<CLAuthorizationStatus, Never>) in
                self.continuation = continuation
                locationManager.requestAlwaysAuthorization()
            } == .authorizedAlways

        default:
            // Present alert guiding user to settings if permission is denied or restricted
            if let viewController {
                presentSettingsAlert(from: viewController)
            }
            return false
        }
    }

    func stop() {
        locationManager.stopMonitoringSignificantLocationChanges()
        nkLog(stop: "Location monitoring stopped")
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

        // Open Realm
        if database.openRealmBackground() {
            let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
            let location = locations.last
            nkLog(tag: self.global.logTagLocation, emoji: .start, message: "Triggered by location change: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")

            Task.detached {
                if let tblAccount = await self.database.getActiveTableAccountAsync(),
                   await !appDelegate.isBackgroundTask {
                    // start the BackgroundTask
                    await MainActor.run {
                        appDelegate.isBackgroundTask = true
                    }

                    let numTransfers = await appDelegate.backgroundSync(tblAccount: tblAccount)
                    nkLog(tag: self.global.logTagLocation, emoji: .success, message: "Triggered by location completed with \(numTransfers) transfers")

                    // end the BackgroundTask
                    await MainActor.run {
                        appDelegate.isBackgroundTask = false
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        nkLog(error: "Location error: \(error.localizedDescription)")
    }
}
