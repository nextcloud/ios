// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Joel Grolimund
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import SwiftUI
import NextcloudKit

/// Hosts the SwiftUI Collectives screens and pushes the Nextcloud Text editor on top of them.
///
/// The SwiftUI `NavigationStack` draws its own navigation bar, so the UIKit bar is only shown for the editor.
final class NCCollectivesNavigationController: NCMainNavigationController {
    private var editorClosed: (() -> Void)?

    static func make(controller: NCMainTabBarController) -> NCCollectivesNavigationController {
        let model = NCCollectivesModel(controller: controller)
        let hostingController = UIHostingController(rootView: NCCollectivesView(model: model))
        let navigationController = NCCollectivesNavigationController(rootViewController: hostingController)
        model.navigationController = navigationController
        return navigationController
    }

    override func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        super.navigationController(navigationController, willShow: viewController, animated: animated)
        setNavigationBarHidden(viewController === viewControllers.first, animated: animated)
    }

    @objc func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if viewController === viewControllers.first, let editorClosed {
            self.editorClosed = nil
            editorClosed()
        }
    }

    /// Opens the page's Markdown file in Nextcloud Text, the editor used by the Collectives web interface.
    /// - Returns: An error if the editor could not be opened.
    func openEditor(page: NCCollectivePage, account: String, onClose: @escaping () -> Void) async -> NKError? {
        guard let serverUrlFileName = NCCollectivesNetworking.shared.serverUrlFileName(page: page, account: account) else {
            return .invalidData
        }
        NCActivityIndicator.shared.start(backgroundView: view)
        let result = await NCNetworking.shared.readFileAsync(serverUrlFileName: serverUrlFileName, account: account)
        NCActivityIndicator.shared.stop()
        guard result.error == .success, let metadata = result.metadata else {
            return result.error == .success ? .invalidData : result.error
        }

        let coordinator = NCDocumentEditorCoordinator(metadata: metadata, image: nil, selectedEditor: global.editorText, delegate: self)
        do {
            guard let editor = try await coordinator.selectEditor() else {
                return .invalidData
            }
            editorClosed = onClose
            pushViewController(editor, animated: true)
            return nil
        } catch let error as NKError {
            return error
        } catch {
            return NKError(error: error)
        }
    }
}
