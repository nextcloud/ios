// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

extension XCUIElement {
    ///
    /// Convenience method to wait for the existence of a `XCUIElement` for the default time defined in the test constants.
    ///
    /// This is the graceful alternative to ``awaitOrFail`` for use cases in which the absence of the `XCUIElement` is not considered an error.
    ///
    /// > Important: This is a candidate for outsourcing into a dedicated library, if not NextcloudKit.
    ///
    /// - Parameters:
    ///     - timeout: The number of seconds to wait.
    ///     - file: File of the call point.
    ///     - line: Source code line of the call point within `file`.
    ///
    /// - Returns: `true`, if the element did show up, otherwise `false`.
    ///
    @discardableResult
    func await(timeout: Double = TestConstants.controlExistenceTimeout) -> Bool {
        guard waitForExistence(timeout: timeout) else {
            return false
        }

        return true
    }
}
