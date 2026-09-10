// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI

class AlbumsViewController: UIViewController {
    var initialAlbum: Album?
    private var displayedAccount: String?
    private var hostingController: UIHostingController<AnyView>?
    @MainActor
    var session: NCSession.Session {
        NCSession.shared.getSession(controller: tabBarController)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        showAlbums(for: session.account)

        // Needed, since we use NCViewerMediaPage to show the media, which expects this!
        navigationController?.navigationBar.prefersLargeTitles = false

        // UI changes
        UIView.appearance(
            whenContainedInInstancesOf: [UIAlertController.self]
        ).tintColor = NCBrandColor.shared.customer

        UIBarButtonItem.appearance(
            whenContainedInInstancesOf: [UINavigationBar.self]
        ).tintColor = NCBrandColor.shared.customer
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: false)

        let currentAccount = session.account

        guard currentAccount != displayedAccount else {
            return
        }

        AlbumsNavigator.shared.pop()
        initialAlbum = nil
        showAlbums(for: currentAccount)
    }

    private func showAlbums(for account: String) {
        displayedAccount = account

        let rootView = AnyView(
            AlbumsRootView(initialAlbum: initialAlbum)
                .environment(\.localAccount, account)
        )

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            self.hostingController = hostingController

            addChild(hostingController)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])

            hostingController.didMove(toParent: self)
        }

        AlbumsManager.shared.setAccount(account)
        AlbumsManager.shared.syncAlbums()
    }
}

struct AccountKey: EnvironmentKey {
    static let defaultValue: String = ""
}

extension EnvironmentValues {
    var localAccount: String {
        get { self[AccountKey.self] }
        set { self[AccountKey.self] = newValue }
    }
}
