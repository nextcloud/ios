//
//  DataProtectionModel.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class DataProtectionModel: ObservableObject {
    
    @Published var requiredDataCollection: Bool = true
    @Published var analysisOfDataCollection: Bool
    
    var isShownFromSettings: Bool = false
    
    init(showFromSettings: Bool = false) {
        self.isShownFromSettings = showFromSettings
        self.analysisOfDataCollection = DataProtectionAgreementManager.shared?.isAllowedAnalysisOfDataCollection() ?? false
    }
    
    func allowAnalysisOfDataCollection(_ allowAnalysisOfDataCollection: Bool) {
        DataProtectionAgreementManager.shared?.allowAnalysisOfDataCollection(allowAnalysisOfDataCollection)
    }
}
