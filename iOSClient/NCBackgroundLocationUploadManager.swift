// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

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
        // .other is CoreLocation's own default (no assumption baked in)
        // and doesn't carry .automotiveNavigation's much higher power/accuracy
        // profile, which is meant for actual turn-by-turn navigation, not an occasional
        // background wake-up trigger, while .fitness only refers to sports
        // activities.
        // FM says:
        //  "Use this activity type to describe positioning in activities
        //  that aren’t covered by one of the other activity types.
        //  This includes activities without a specific user intention, for
        //  example, positioning while a user sits on a bench interacting with
        //  a device."
        locationManager.activityType = .other
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        // let status = locationManager.authorizationStatus
        locationManager.startMonitoringSignificantLocationChanges()
        // Diagnostic only: confirms this was actually reached (and thus that
        // sceneDidEnterBackground's gating conditions held) — there was
        // previously no way to tell "monitoring never armed" apart from
        // "armed, but the OS never delivered/relaunched for an event" from
        // the log alone.
        nkLog(debug: "Location monitoring started")
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
        let location = locations.last

        // Logged before any of the guards below, deliberately: every early
        // return here is silent, so an absent "Triggered by location change"
        // used to mean either "the OS never delivered an update" or "it was
        // delivered and then discarded" — with no way to tell which. Since
        // monitoring has never been observed to fire in the field, that
        // distinction is the whole question, and it can only be answered if
        // delivery itself is recorded first.
        nkLog(tag: self.global.logTagLocation,
              emoji: .info,
              message: "Location update delivered: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")

        // Must work only in background
        guard isAppInBackground else {
            nkLog(tag: self.global.logTagLocation, emoji: .stop, message: "Location update ignored: the app is in the foreground")
            return
        }

        // Open Realm
        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagLocation, emoji: .error, message: "Failed to open Realm in Location Manager")
            return
        }

        nkLog(tag: self.global.logTagLocation, emoji: .start, message: "Triggered by location change: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")

        Task.detached {
            await NCAutoUpload.shared.autoUploadBackgroundSync()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        nkLog(error: "Location error: \(error.localizedDescription)")
    }
}
