//
//  NCMediaViewRepresentable.swift
//  Nextcloud
//
//  Created by Dhanesh on 05/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import UIKit

struct NCMediaViewRepresentable: UIViewControllerRepresentable {
    @Environment(\.localAccount) private var account
    @Binding var ncMedia: NCMedia?

    func makeCoordinator() -> Coordinator {
        let storyboard = UIStoryboard(name: "NCMedia", bundle: nil)
        let media = storyboard.instantiateViewController(identifier: "NCMedia.storyboard") { coder in
            Coordinator(coder: coder)
        }
        media.albumAccount = account
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
        var onReady: (() -> Void)?
        var prepareTask: Task<Void, Never>?
        private var selectionReady = false

        override var session: NCSession.Session {
            NCSession.shared.getSession(account: albumAccount)
        }

        override var controller: NCMainTabBarController? {
            SceneManager.shared.getController(account: albumAccount)
        }

        override var sceneIdentifier: String {
            controller?.sceneIdentifier ?? ""
        }

        override var windowScene: UIWindowScene? {
            viewIfLoaded?.window?.windowScene
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            // Keep Media's selection bookkeeping without its share/move/delete toolbar.
            tabBarSelect = NCMediaSelectTabBar(viewController: self)
            collectionView.dragInteractionEnabled = false
            collectionView.isUserInteractionEnabled = false
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
                await self.loadDataSource()
                guard !Task.isCancelled else { return }
                // The normal search API requires an attached view outside edit mode.
                await self.searchMediaTask?.value
                await self.searchMediaUI(true)
                guard !Task.isCancelled else { return }
                self.isEditMode = true
                self.selectionReady = true
                self.collectionView.isUserInteractionEnabled = true
                self.onReady?()
            }
        }

        override func viewDidDisappear(_ animated: Bool) {
            prepareTask?.cancel()
            super.viewDidDisappear(animated)
        }
    }
}
