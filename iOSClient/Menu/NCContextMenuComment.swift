// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import NextcloudKit

/// A context menu for comment actions (edit, delete).
/// See ``NCActivity`` for usage details.
class NCContextMenuComment: NSObject {
    let tableComments: tableComments
    let metadata: tableMetadata
    let viewController: UIViewController?
    private let utility = NCUtility()

    init(tableComments: tableComments, metadata: tableMetadata, viewController: UIViewController?) {
        self.tableComments = tableComments
        self.metadata = metadata
        self.viewController = viewController
    }

    func viewMenu() -> UIMenu {
        UIMenu(title: "", children: [makeEditAction(), makeDeleteAction()])
    }

    private func makeEditAction() -> UIAction {
        UIAction(
            title: NSLocalizedString("_edit_comment_", comment: ""),
            image: utility.loadImage(named: "pencil", colors: [NCBrandColor.shared.iconImageColor])
        ) { _ in
            let alert = UIAlertController(title: NSLocalizedString("_edit_comment_", comment: ""), message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("_cancel_", comment: ""), style: .cancel, handler: nil))

            alert.addTextField { textField in
                textField.placeholder = NSLocalizedString("_new_comment_", comment: "")
                textField.text = self.tableComments.message
            }

            alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { _ in
                guard let message = alert.textFields?.first?.text, !message.isEmpty else { return }

                NextcloudKit.shared.updateComments(
                    fileId: self.metadata.fileId,
                    messageId: self.tableComments.messageId,
                    message: message,
                    account: self.metadata.account
                ) { task in
                    Task {
                        let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                            account: self.metadata.account,
                            path: self.metadata.fileId,
                            name: "updateComments"
                        )
                        await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    }
                } completion: { _, _, error in
                    if error == .success {
                        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataNCShare)
                    } else {
                        Task { @MainActor in
                            await showErrorBanner(controller: self.viewController?.tabBarController, text: error.errorDescription, errorCode: error.errorCode)
                        }
                    }
                }
            })

            self.viewController?.present(alert, animated: true)
        }
    }

    private func makeDeleteAction() -> UIAction {
        UIAction(
            title: NSLocalizedString("_delete_comment_", comment: ""),
            image: utility.loadImage(named: "trash", colors: [.red]),
            attributes: .destructive
        ) { _ in
            NextcloudKit.shared.deleteComments(
                fileId: self.metadata.fileId,
                messageId: self.tableComments.messageId,
                account: self.metadata.account
            ) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(
                        account: self.metadata.account,
                        path: self.metadata.fileId,
                        name: "deleteComments"
                    )
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            } completion: { _, _, error in
                if error == .success {
                    (self.viewController as? NCActivity)?.loadComments()
                } else {
                    Task { @MainActor in
                        await showErrorBanner(controller: self.viewController?.tabBarController, text: error.errorDescription, errorCode: error.errorCode)
                    }
                }
            }
        }
    }
}
