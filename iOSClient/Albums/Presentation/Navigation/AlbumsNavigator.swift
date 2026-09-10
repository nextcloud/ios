// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

final class AlbumsNavigator: ObservableObject {
    static let shared = AlbumsNavigator()
    @Published var current: AlbumsRoutes?

    private init() {}

    func push(_ route: AlbumsRoutes) {
        current = route
    }

    func pop() {
        current = nil
    }
}
