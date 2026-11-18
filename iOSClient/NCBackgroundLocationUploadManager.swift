// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import CoreLocation
import NextcloudKit
import UIKit

// Core Location delivers delegate callbacks on the run loop where its manager was created.
@MainActor
class NCBackgroundLocationUploadManager: NSObject, @preconcurrency CLLocationManagerDelegate {
    static let shared = NCBackgroundLocationUploadManager()

    private let global = NCGlobal.shared
    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Bool, Never>?

    var authorizationStatus: CLAuthorizationStatus { locationManager.authorizationStatus }

    private override init() {
        super.init()

        locationManager.delegate = self
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
    }

    func start() {
        locationManager.startMonitoringSignificantLocationChanges()
    }

    /// Waits for the initial system prompt, whose choices all change the authorization status.
    func requestAuthorizationAlwaysAsync() async -> Bool {
        if authorizationStatus == .authorizedAlways { return true }
        guard authorizationStatus == .notDetermined, authorizationContinuation == nil, UIApplication.shared.applicationState == .active else { return false }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            locationManager.requestAlwaysAuthorization()
        }
    }

    func stop() {
        locationManager.stopMonitoringSignificantLocationChanges()
        nkLog(stop: "Location monitoring stopped")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard status != .notDetermined, let continuation = authorizationContinuation else { return }

        authorizationContinuation = nil
        continuation.resume(returning: status == .authorizedAlways)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Must work only in background
        guard isAppInBackground else {
            return
        }

        // Open Realm
        guard NCManageDatabase.shared.openRealmBackground() else {
            nkLog(tag: self.global.logTagLocation, emoji: .error, message: "Failed to open Realm in Location Manager")
            return
        }

        let location = locations.last
        nkLog(tag: self.global.logTagLocation, emoji: .start, message: "Triggered by location change: \(location?.coordinate.latitude ?? 0), \(location?.coordinate.longitude ?? 0)")

        Task.detached {
            await NCAutoUpload.shared.autoUploadBackgroundSync()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        nkLog(error: "Location error: \(error.localizedDescription)")
    }
}
