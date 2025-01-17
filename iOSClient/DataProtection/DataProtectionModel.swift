//
//  DataProtectionModel.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 STRATO AG
//

import Foundation

class DataProtectionModel: ObservableObject {
    
    @Published var requiredDataCollection: Bool = true
    @Published var analysisOfDataCollection: Bool
    @Published var redirectToSettings: Bool = false
    
    var isShownFromSettings: Bool = false
    
    init(showFromSettings: Bool = false) {
        self.isShownFromSettings = showFromSettings
        self.analysisOfDataCollection = DataProtectionAgreementManager.shared.isAllowedAnalysisOfDataCollection()
    }
    
    func allowAnalysisOfDataCollection(_ allowAnalysisOfDataCollection: Bool) {
        DataProtectionAgreementManager.shared.allowAnalysisOfDataCollection(allowAnalysisOfDataCollection) {
            [weak self] in self?.redirectToSettings = true
        }
    }
    
    func cancelOpenSettings() {
        self.analysisOfDataCollection = DataProtectionAgreementManager.shared.isAllowedAnalysisOfDataCollection()
    }
    
    func openSettings() {
        DispatchQueue.main.async {
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
            }
        }
        self.analysisOfDataCollection = DataProtectionAgreementManager.shared.isAllowedAnalysisOfDataCollection()
    }
    
    func saveSettings() {
        DataProtectionAgreementManager.shared.saveSettings()
    }
}
