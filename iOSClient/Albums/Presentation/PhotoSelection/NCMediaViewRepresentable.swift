// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct NCMediaViewRepresentable: UIViewControllerRepresentable {
    private unowned let controller: NCMainTabBarController

    @Binding var ncMedia: NCMedia?

    init(controller: NCMainTabBarController, ncMedia: Binding<NCMedia?>) {
        self.controller = controller
        _ncMedia = ncMedia
    }

    func makeCoordinator() -> Coordinator {
        let storyboard = UIStoryboard(name: "NCMedia", bundle: nil)
        let media = storyboard.instantiateViewController(identifier: "NCMedia.storyboard") { coder in
            Coordinator(coder: coder)
        }
        media.albumAccount = controller.account
        media.albumsController = controller
        return media
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let media = context.coordinator
        media.onReady = { [weak media] in
            ncMedia = media
        }
        let navigation = UINavigationController(rootViewController: media)
        navigation.setNavigationBarHidden(true, animated: false)
        return navigation
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: UINavigationController, coordinator: Coordinator) {
        coordinator.prepareTask?.cancel()
        coordinator.onReady = nil
    }

    // Keeps the album-specific session and selection lifecycle outside NCMedia.
    final class Coordinator: NCMedia {
        var albumAccount = ""
        weak var albumsController: NCMainTabBarController?
        var onReady: (() -> Void)?
        var prepareTask: Task<Void, Never>?
        private var selectionReady = false

        override var session: NCSession.Session {
            NCSession.shared.getSession(account: albumAccount)
        }

        override var controller: NCMainTabBarController? {
            albumsController
        }

        override var sceneIdentifier: String {
            controller?.sceneIdentifier ?? ""
        }

        override var windowScene: UIWindowScene? {
            viewIfLoaded?.window?.windowScene
        }

        override var allowsSearchWhileSelecting: Bool { true }

        override var isMediaPresentationActive: Bool { isViewActived }

        override func viewDidLoad() {
            super.viewDidLoad()
            // Keep Media's selection bookkeeping without its share/move/delete toolbar.
            tabBarSelect = NCMediaSelectTabBar(viewController: self)
            collectionView.dragInteractionEnabled = false
            isEditMode = true
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            if selectionReady {
                collectionView.isUserInteractionEnabled = true
            }
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !selectionReady, prepareTask == nil else { return }
            prepareTask = Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.prepareTask = nil }

                // This controller is presented in a sheet, not as the selected Media tab.
                await self.loadDataSource(forced: true)
                guard !Task.isCancelled else { return }
                self.selectionReady = true
                self.collectionView.isUserInteractionEnabled = true
                self.onReady?()

                self.searchNewMedia()
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            prepareTask?.cancel()
            super.viewDidDisappear(animated)
        }
    }
}
