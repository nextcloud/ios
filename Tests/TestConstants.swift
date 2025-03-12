// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2023 Marcel Müller
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

///
/// Immutable test configuration.
///
enum TestConstants {
    ///
    /// The default number of seconds to wait for the appearance of user interface controls during user interface tests.
    ///
    static let controlExistenceTimeout: Double = 10

    ///
    /// The full base URL for the server to run against.
    ///
    static let server = "http://localhost:8080"

    ///
    /// Default user name to sign in with.
    ///
    static let username = "admin"

    ///
    /// Password of the default user name to sign in with.
    ///
    static let password = "admin"

    ///
    /// Account identifier of the default user to test with.
    ///
    static let account = "\(username) \(server)"
}
