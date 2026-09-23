// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

final class AlbumsNavigator: ObservableObject {
    @Published var current: AlbumsRoutes?
    @Published private(set) var coverImage: UIImage?

    func push(_ route: AlbumsRoutes, coverImage: UIImage? = nil) {
        self.coverImage = coverImage
        current = route
    }

    func pop() {
        current = nil
        coverImage = nil
    }
}
