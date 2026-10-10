// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import Combine

class AlbumsViewController: UIViewController {
    var initialAlbum: Album?
    private var displayedAccount: String?
    private(set) var listViewModel: AlbumsListViewModel?
    private(set) var detailsViewModel: AlbumDetailsViewModel?
    private var cancellables: Set<AnyCancellable> = []
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

        navigationController?.setNavigationBarHidden(false, animated: false)

        guard let controller, !controller.account.isEmpty else { return }
        if controller.account == displayedAccount {
            if detailsViewModel == nil {
                AlbumsManager.shared.syncAlbums(for: controller.account)
            }
        } else {
            updateAlbumsIfNeeded(for: controller)
        }
    }

    private func updateAlbumsIfNeeded(for controller: NCMainTabBarController) {
        guard controller.account != displayedAccount else { return }

        let isChangingAccount = displayedAccount != nil
        if isChangingAccount {
            initialAlbum = nil
        }
        showAlbums(for: controller)
        if isChangingAccount {
            // Both list and detail can receive the notification; always return to the list.
            if let root = navigationController?.viewControllers.first as? AlbumsViewController {
                navigationController?.popToViewController(root, animated: false)
            }
        }
    }

    private func showAlbums(for controller: NCMainTabBarController) {
        let account = controller.account
        displayedAccount = account
        let tintColor = NCBrandColor.shared.getElement(account: account)
        view.tintColor = tintColor
        navigationController?.navigationBar.tintColor = tintColor
        cancellables.removeAll()
        let navigator = AlbumsNavigator()
        let rootView: AnyView

        if let album = initialAlbum {
            let viewModel = AlbumDetailsViewModel(controller: controller, album: album, navigator: navigator)
            detailsViewModel = viewModel
            listViewModel = nil
            viewModel.$screenTitle.combineLatest(viewModel.$isLoading)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    NCAlbumsNavigationController.configureNavigationItems(for: self)
                }
                .store(in: &cancellables)
            rootView = AnyView(AlbumDetailsScreen(controller: controller, viewModel: viewModel))
        } else {
            let viewModel = AlbumsListViewModel(controller: controller, navigator: navigator)
            listViewModel = viewModel
            detailsViewModel = nil
            rootView = AnyView(AlbumsListScreen(controller: controller, viewModel: viewModel))
        }
        NCAlbumsNavigationController.configureNavigationItems(for: self)
        navigator.$current
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak controller] route in
                guard let self, let controller,
                      controller.account == self.displayedAccount else { return }
                if case let .albumDetails(album) = route {
                    guard album.account == controller.account else { return }
                    let detailController = AlbumsViewController()
                    detailController.initialAlbum = album
                    self.navigationController?.pushViewController(detailController, animated: true)
                } else if self.detailsViewModel != nil,
                          self.navigationController?.topViewController === self {
                    self.navigationController?.popViewController(animated: true)
                }
            }
            .store(in: &cancellables)
        let content = AnyView(rootView.id(account).environment(\.localAccount, account).hideTopScrollEdgeEffect())

        if let hostingController {
            hostingController.rootView = content
            hostingController.view.tintColor = tintColor
        } else {
            let hostingController = UIHostingController(rootView: content)
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
        if detailsViewModel == nil {
            AlbumsManager.shared.syncAlbums(for: account)
        }
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
