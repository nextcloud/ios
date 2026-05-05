// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

@MainActor
final class NCFocusedAutoUploadScreenDimmer {
    static let shared = NCFocusedAutoUploadScreenDimmer()

    private var originalBrightness: CGFloat?
    private var originalIdleTimerDisabled: Bool?
    private var keepAwakeTask: Task<Void, Never>?

    private init() {}

    func startKeepingScreenAwake() {
        if originalIdleTimerDisabled == nil {
            originalIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        }

        UIApplication.shared.isIdleTimerDisabled = true
        startKeepAwakeTask()
    }

    func dimScreen() {
        if originalBrightness == nil {
            originalBrightness = UIScreen.main.brightness
        }

        startKeepingScreenAwake()
        UIScreen.main.brightness = 0
    }

    func restoreScreen() {
        keepAwakeTask?.cancel()
        keepAwakeTask = nil

        if let originalBrightness {
            UIScreen.main.brightness = originalBrightness
        }

        if let originalIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = originalIdleTimerDisabled
        }

        originalBrightness = nil
        originalIdleTimerDisabled = nil
    }

    private func startKeepAwakeTask() {
        guard keepAwakeTask == nil else {
            return
        }

        keepAwakeTask = Task { @MainActor in
            while !Task.isCancelled {
                UIApplication.shared.isIdleTimerDisabled = true
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
