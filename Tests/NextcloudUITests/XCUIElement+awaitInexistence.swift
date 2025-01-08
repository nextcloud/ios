// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

extension XCUIElement {
    ///
    /// Convenience method to wait for the inexistence of a `XCUIElement` for the default time defined in the test constants.
    /// This will throw an error, if the user interface element did not appear or exist within given timeout.
    ///
    /// > Important: This is a candidate for outsourcing into a dedicated library, if not NextcloudKit.
    ///
    /// - Parameters:
    ///     - timeout: The number of seconds to wait.
    ///     - file: File of the call point.
    ///     - line: Source code line of the call point within `file`.
    ///
    /// - Returns: `true`, if the element did disappear, otherwise `false`.
    ///
    @discardableResult
    func awaitInexistence(timeout: Double = TestConstants.controlExistenceTimeout, file: StaticString = #file, line: UInt = #line) -> Bool {
        guard waitForNonExistence(timeout: timeout) else {
            XCTFail("Expected element did not exist after \(timeout) seconds.", file: file, line: line)
            return false
        }

        return true
    }
}
