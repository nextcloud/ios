//
//  SelectionManager.swift
//  Nextcloud
//
//  Created by Milen on 12.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

class SelectionManager: ObservableObject {
    @Published var isInSelectMode = false
    @Published var selectedMetadatas: [tableMetadata] = []

    func cancelSelection() {
        isInSelectMode = false
        selectedMetadatas.removeAll()
    }
}
