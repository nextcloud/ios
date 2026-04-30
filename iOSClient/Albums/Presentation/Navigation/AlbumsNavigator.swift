//
//  AlbumsNavigator.swift
//  Nextcloud
//
//  Created by Dhanesh on 11/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

final class AlbumsNavigator: ObservableObject {
    
    static let shared = AlbumsNavigator()
    
    @Published var current: AlbumsRoutes? = nil
    
    private init() {}
    
    func push(_ route: AlbumsRoutes) {
        current = route
    }
    
    func pop() {
        current = nil
    }
}
