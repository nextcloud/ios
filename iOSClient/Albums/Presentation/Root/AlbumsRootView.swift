// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AlbumsRootView: View {
    private unowned let controller: NCMainTabBarController
    var initialAlbum: Album?
    @State private var didApplyInitialRoute = false
    @StateObject private var navigator: AlbumsNavigator

    init(controller: NCMainTabBarController, initialAlbum: Album? = nil) {
        self.controller = controller
        self.initialAlbum = initialAlbum
        _navigator = StateObject(wrappedValue: AlbumsNavigator())
    }

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
            AlbumsListScreen(
                controller: controller,
                viewModel: .init(controller: controller, navigator: navigator)
            )
                // Explicitly use 'AlbumsRoutes.self' here to solve the inference error
                .navigationDestination(for: AlbumsRoutes.self) { route in
                    switch route {
                    case .albumDetails(let album):
                        AlbumDetailsScreen(
                            controller: controller,
                            album: album,
                            navigator: navigator
                        )
                    }
                }
        }
        .hideTopScrollEdgeEffect()
        .environment(\.localAccount, controller.account)
        .onAppear {
            guard !didApplyInitialRoute else { return }
            didApplyInitialRoute = true
            if let initialAlbum {
                navigator.push(.albumDetails(album: initialAlbum))
            } else {
                navigator.pop()
            }
        }
    }
}
