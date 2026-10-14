// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// State of the collectives overview and shared context for all Collectives screens.
@MainActor
@Observable
final class NCCollectivesModel {
    var collectives: [NCCollective] = []
    var isLoading = false
    var error: NKError?
    var account: String

    @ObservationIgnored weak var controller: NCMainTabBarController?
    @ObservationIgnored weak var navigationController: NCCollectivesNavigationController?
    @ObservationIgnored private let networking = NCCollectivesNetworking.shared

    init(controller: NCMainTabBarController?) {
        self.controller = controller
        self.account = NCSession.shared.getSession(controller: controller).account
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        switch await networking.getCollectives(account: account) {
        case .success(let collectives):
            self.collectives = collectives.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            error = nil
        case .failure(let error):
            self.error = error
        }
    }

    func switchAccount(_ account: String) async {
        self.account = account
        collectives = []
        await load()
    }

    func showError(_ error: NKError) {
        Task {
            let windowScene = SceneManager.shared.getWindowScene(controller: controller)
            await showErrorBanner(windowScene: windowScene, error: error)
        }
    }

    func openEditor(page: NCCollectivePage, onClose: @escaping () -> Void) async {
        guard let navigationController else { return }
        if let error = await navigationController.openEditor(page: page, account: account, onClose: onClose) {
            showError(error)
        }
    }
}
