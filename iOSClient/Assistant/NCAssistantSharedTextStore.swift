// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

enum NCAssistantSharedTextStore {
    private static let sharedTextKey = "assistant.sharedText"
    private static let sharedTextDateKey = "assistant.sharedTextDate"
    private static var appGroupIdentifier: String {
        NCBrandOptions.shared.capabilitiesGroup
    }

    /// Saves text received from the Assistant share extension into the shared App Group container.
    ///
    /// - Parameter text: Text selected by the user in another app.
    static func save(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty,
              let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        defaults.set(trimmedText, forKey: sharedTextKey)
        defaults.set(Date(), forKey: sharedTextDateKey)
        defaults.synchronize()
    }

    /// Loads and removes the latest text received from the Assistant share extension.
    ///
    /// - Returns: Previously saved text, or `nil` when no valid text is available.
    static func loadAndClear() -> String? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let text = defaults.string(forKey: sharedTextKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }

        defaults.removeObject(forKey: sharedTextKey)
        defaults.removeObject(forKey: sharedTextDateKey)
        defaults.synchronize()

        return text
    }

    /// Removes any pending shared text from the App Group container.
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        defaults.removeObject(forKey: sharedTextKey)
        defaults.removeObject(forKey: sharedTextDateKey)
        defaults.synchronize()
    }
}
