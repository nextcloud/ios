//
//  DataProtectionModel.swift
//  Nextcloud
//
//  Created by Mariia Perehozhuk on 25.11.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class DataProtectionModel: ObservableObject {
    
    @Published var requiredDataCollection: Bool = false
    @Published var analysisOfDataCollection: Bool = false
}
