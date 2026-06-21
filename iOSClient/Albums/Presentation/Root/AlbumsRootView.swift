//
//  AlbumsRootView.swift
//  Nextcloud
//
//  Created by Dhanesh on 24/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct AlbumsRootView: View {
    
    @Environment(\.localAccount) var localAccount: String
    
    @StateObject private var navigator = AlbumsNavigator.shared
    
    var body: some View {

        NavigationStack(path: Binding(
            get: {
                // If navigator.current is not nil, treat it as a 1-item stack path
                navigator.current.map { [$0] } ?? []
            },
            set: { path in
                // If the stack path is emptied (e.g., back button), clear navigator
                if path.isEmpty { navigator.pop() }
            }
        )) {
            AlbumsListScreen(viewModel: .init(account: localAccount))
                // Explicitly use 'AlbumsRoutes.self' here to solve the inference error
                .navigationDestination(for: AlbumsRoutes.self) { route in
                    switch route {
                    case .albumDetails(let album):
                        AlbumDetailsScreen(account: localAccount, album: album)
                    }
                }
        }
    }
}
