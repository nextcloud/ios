// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import XCTest

///
/// Errors specific to the automated user interface tests.
///
/// > Important: This is a candidate for outsourcing into a dedicated library, if not NextcloudKit.
///
enum UITestError: Error {
    ///
    /// A very generic case for errors like disappointing optionals.
    ///
    case missingValue

    ///
    /// The server responded different from how it was assumed during writing of the test.
    ///
    case unexpectedResponse

    ///
    /// A user interface element was expected to appear or exist which it did or does not.
    ///
    case waitForExistence(XCUIElement)
}
