//
//  AnalyticsHelper.swift
//  Nextcloud
//
//  Created by Amrut Waghmare on 10/06/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class AnalyticsHelper: NSObject, AnalyticsService {
    
    @objc static let shared = AnalyticsHelper()

    private var analyticsServices: [AnalyticsService]

    private override init() {
        // Initialize the analytics services
        let moEngageAnalytics = MoEngageAnalytics()
        moEngageAnalytics.trackAppId()
        analyticsServices = [moEngageAnalytics]
        super.init()
    }

    func trackEvent(eventName: AnalyticEvents, properties: [String: Any]? = nil) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackEvent(eventName: eventName, properties: properties) }
        }
    }
    
    func trackUserData() {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackUserData() }
        }
    }

    func trackUsedStorageData(quotaUsed: Int64) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackUsedStorageData(quotaUsed: quotaUsed) }
        }
    }
    
    @objc func trackAutoUpload(isEnable: Bool) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackAutoUpload(isEnable: isEnable) }
        }
    }
    
    func trackAppVersion(oldVersion: String?) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackAppVersion(oldVersion: oldVersion) }
        }
    }

    func trackLogout() {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackLogout() }
        }
    }

    func trackCreateFile(metadata: tableMetadata) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackCreateFile(metadata: metadata) }
        }
    }

    func trackEventWithMetadata(eventName: AnalyticEvents, metadata: tableMetadata) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackEventWithMetadata(eventName: eventName, metadata: metadata) }
        }
    }
    
    func trackCreateVoiceMemo(size: Int64, date: Date) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackCreateVoiceMemo(size: size, date: date) }
        }
    }

    func trackCreateFolder(isEncrypted: Bool, creationDate: Date) {
        DispatchQueue.global(qos: .background).async {
            self.analyticsServices.forEach { $0.trackCreateFolder(isEncrypted: isEncrypted, creationDate: creationDate) }
        }
    }
    
//    func displayInAppNotification() {
//        self.analyticsServices.forEach { $0.displayInAppNotification() }
//    }


}
