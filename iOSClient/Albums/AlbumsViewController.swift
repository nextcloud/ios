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
    private var controller: NCMainTabBarController? {
        tabBarController as? NCMainTabBarController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Needed, since we use NCViewerMediaPage to show the media, which expects this!
        navigationController?.navigationBar.prefersLargeTitles = false

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeUser),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let sourceController = notification.userInfo?["controller"] as? NCMainTabBarController,
                  sourceController === self.controller,
                  let account = notification.userInfo?["account"] as? String,
                  account == sourceController.account else { return }

            self.updateAlbumsIfNeeded(for: sourceController)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: false)

        guard let controller, !controller.account.isEmpty else { return }
        if controller.account == displayedAccount {
            AlbumsManager.shared.syncAlbums(for: controller.account)
        } else {
            updateAlbumsIfNeeded(for: controller)
        }
    }

    private func updateAlbumsIfNeeded(for controller: NCMainTabBarController) {
        guard controller.account != displayedAccount else { return }

        initialAlbum = nil
        showAlbums(for: controller)
    }

    private func showAlbums(for controller: NCMainTabBarController) {
        let account = controller.account
        displayedAccount = account
        let tintColor = NCBrandColor.shared.getElement(account: account)
        view.tintColor = tintColor
        navigationController?.navigationBar.tintColor = tintColor

        let rootView = AnyView(
            AlbumsRootView(controller: controller, initialAlbum: initialAlbum)
                .id(controller.account)
        )

        if let hostingController {
            hostingController.rootView = rootView
            hostingController.view.tintColor = tintColor
        } else {
            let hostingController = UIHostingController(rootView: rootView)
            self.hostingController = hostingController

            addChild(hostingController)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.tintColor = tintColor
            view.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])

            hostingController.didMove(toParent: self)
        }

        AlbumsManager.shared.syncAlbums(for: account)
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
