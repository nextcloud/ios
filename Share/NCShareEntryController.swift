// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Loads the SwiftUI interface directly as the extension's principal controller.
@MainActor
final class NCShareEntryController: UIHostingController<NCShareView> {
    private let model: NCShareViewModel

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        model.start(context: extensionContext, presenter: self)
    }
}
