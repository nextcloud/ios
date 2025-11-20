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
            let status = await NextcloudKit.shared.getUserStatusAsync(account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
                                                                                                name: "getUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                }
            }

            selectedStatus = status.status
        }
    }

    func setStatus(account: String) {
        Task {
            await NextcloudKit.shared.setUserStatusAsync(status: selectedStatus ?? "", account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
                                                                                                name: "setUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
                    self.canDismiss = true
                }
            }
        }
    }

    func setAccountUserStatus(account: String) {
        NextcloudKit.shared.getUserStatus(account: account) { task in
            Task {
                let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
                                                                                            name: "getUserStatus")
                await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
            }
        } completion: { account, clearAt, icon, message, messageId, messageIsPredefined, status, statusIsUserDefined, _, _, error in
            if error == .success {
                Task {
                    await NCManageDatabase.shared.setAccountUserStatusAsync(userStatusClearAt: clearAt,
                                                                            userStatusIcon: icon,
                                                                            userStatusMessage: message,
                                                                            userStatusMessageId: messageId,
                                                                            userStatusMessageIsPredefined: messageIsPredefined,
                                                                            userStatusStatus: status,
                                                                            userStatusStatusIsUserDefined: statusIsUserDefined,
                                                                            account: account)
                }
            }
        }
    }
}
