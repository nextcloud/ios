// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import LucidBanner

/// Loads the SwiftUI interface directly as the extension's principal controller.
@MainActor
final class NCShareEntryController: UIHostingController<NCShareView> {
    private let model: NCShareViewModel
    private var hasAppeared = false

    // The extension system instantiates the principal class through Objective-C.
    @objc init() {
        let model = NCShareViewModel()
        self.model = model
        super.init(rootView: NCShareView(model: model))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("This extension is initialized through NSExtensionPrincipalClass.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Prepare local state before the first appearance to avoid an empty initial screen.
        model.start(context: extensionContext, presenter: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Scene-bound banners and passcode presentation require an attached window.
        // Returning from a presented sheet must not restart the share request.
        guard !hasAppeared, !model.isClosing else { return }
        hasAppeared = true
        if let windowScene = view.window?.windowScene {
            model.banner = LucidBannerRegistry.shared.banner(for: windowScene)
        }
        model.validateAccountAndRequestPasscode()
    }
}
