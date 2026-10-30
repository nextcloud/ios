// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Owns the mandatory lock above one scene's app window, independently of modal presentations.
@MainActor
final class NCPasscodeWindow: UIWindow {
    private weak var mainWindow: UIWindow?

    init(mainWindow: UIWindow, windowScene: UIWindowScene,
         completion: @escaping @MainActor (NCPasscodeModel.Result) -> Void) {
        self.mainWindow = mainWindow
        super.init(windowScene: windowScene)
        // Above the app's banners, PopupView windows and privacy screen.
        windowLevel = .alert + 2
        backgroundColor = .systemBackground
        overrideUserInterfaceStyle = mainWindow.overrideUserInterfaceStyle
        accessibilityIdentifier = "passcode.window"
        accessibilityViewIsModal = true

        let model = NCPasscodeModel(mode: .authenticate, allowCancel: false)
        let controller = UIHostingController(rootView: NCPasscodeView(model: model, windowScene: windowScene))
        controller.isModalInPresentation = true
        rootViewController = controller
        model.onCompletion = { [weak self] result in
            guard let self, result == .authenticated || result == .reset else { return }
            self.hide()
            completion(result)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Show immediately without presenting or dismissing any controller in the app window.
    func show() {
        makeKeyAndVisible()
    }

    /// Release the lock and restore focus to the owning app window when its scene is active.
    func hide() {
        let restoreFocus = isKeyWindow && windowScene?.activationState == .foregroundActive
        isHidden = true
        rootViewController = nil
        if restoreFocus {
            mainWindow?.makeKey()
        }
    }
}
