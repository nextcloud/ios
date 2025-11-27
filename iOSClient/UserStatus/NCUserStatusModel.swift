// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCUserStatusModel {
    struct UserStatus: Hashable {
        let name: String
        let titleKey: String
        var descriptionKey: String = ""
    }

    @ObservationIgnored var userStatuses: [UserStatus] = [
        .init(name: "online", titleKey: "_online_"),
        .init(name: "away", titleKey: "_away_"),
        .init(name: "dnd", titleKey: "_dnd_", descriptionKey: "_dnd_description_"),
        .init(name: "invisible", titleKey: "_invisible_", descriptionKey: "_invisible_description_")
    ]

    var selectedStatus: String?
    var canDismiss = false

    @ObservationIgnored let account: String

    init(account: String) {
        self.account = account

        if let capabilities = NCNetworking.shared.capabilities[account], capabilities.userStatusSupportsBusy {
            userStatuses.insert(.init(name: "busy", titleKey: "_busy_"), at: 2)
        }
    }

    func getStatusDetails(name: String) -> (statusImage: UIImage?, statusImageColor: UIColor, statusMessage: String, descriptionMessage: String) {
        return NCUtility().getUserStatus(userIcon: nil, userStatus: name, userMessage: nil)
    }

    func getStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.getUserStatusAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account, name: "getUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error == .success {
                selectedStatus = result.status
            } else {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func setStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.setUserStatusAsync(status: selectedStatus ?? "", account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account, name: "setUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    self.canDismiss = true
                }
            }

            if result.error != .success {
                NCContentPresenter().showError(error: result.error)
            }
        }
    }

    func setAccountUserStatus(account: String) {
        Task {
            let result = await NextcloudKit.shared.getUserStatusAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account, name: "getUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            if result.error != .success {
                NCContentPresenter().showError(error: result.error)
            }

            await NCManageDatabase.shared.setAccountUserStatusAsync(userStatusClearAt: result.clearAt,
                                                                    userStatusIcon: result.icon,
                                                                    userStatusMessage: result.message,
                                                                    userStatusMessageId: result.messageId,
                                                                    userStatusMessageIsPredefined: result.messageIsPredefined,
                                                                    userStatusStatus: result.status,
                                                                    userStatusStatusIsUserDefined: result.statusIsUserDefined,
                                                                    account: result.account)
        }
    }
}
