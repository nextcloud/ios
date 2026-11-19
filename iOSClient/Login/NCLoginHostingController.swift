// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKitUI
import SwiftUI
import UIKit

/// Hosts the shared NextcloudKitUI login for every place the app shows its login screen.
final class NCLoginHostingController: UIHostingController<ServerAddressView> {
    private let coordinator: NCLoginCoordinator
    private var hasAppeared = false

    init(controller: NCMainTabBarController?, presentation: NCLoginCoordinator.Presentation) {
        let coordinator = NCLoginCoordinator(controller: controller, presentation: presentation)

        let rootView = ServerAddressView(backgroundColor: .constant(Color(uiColor: NCBrandColor.shared.customer)),
                                         brandImage: Image("logo"),
                                         sharedAccounts: coordinator.loadSharedAccounts(),
                                         userAgent: userAgent,
                                         configuration: coordinator.makeConfiguration()) { host, name, password in
            try await coordinator.addAccount(host: host, user: name, password: password)
        }

        self.coordinator = coordinator

        super.init(rootView: rootView)

        coordinator.presenter = self
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.customer

        Task {
            _ = await NCAccount().updateAppsShareAccounts()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !hasAppeared else { return }

        hasAppeared = true

        Task {
            await coordinator.runAppConfigAutoLoginIfNeeded()
        }
    }
}
