// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCUserStatusModel {
    struct UserStatus: Hashable {
        let names: [String]
        let titleKey: String
        var descriptionKey: String = ""
    }

    @ObservationIgnored var userStatuses: [UserStatus] = [
        .init(names: ["online"], titleKey: "_online_"),
        .init(names: ["away"], titleKey: "_away_"),
        .init(names: ["dnd"], titleKey: "_dnd_", descriptionKey: "_dnd_description_"),
        .init(names: ["invisible", "offline"], titleKey: "_invisible_", descriptionKey: "_invisible_description_")
    ]

    var selectedStatus: String?
    var userStatusSupportsBusy = false
    var canDismiss = false

    @ObservationIgnored let account: String

    init(account: String) {
        self.account = account

        if let capabilities = NCNetworking.shared.capabilities[account], capabilities.userStatusSupportsBusy {
//            userStatusSupportsBusy = true
            userStatuses.insert(.init(names: ["busy"], titleKey: "_busy_"), at: 2)
        }
    }

    func getStatusDetails(name: String) -> (statusImage: UIImage?, statusImageColor: UIColor, statusMessage: String, descriptionMessage: String) {
        return NCUtility().getUserStatus(userIcon: nil, userStatus: name, userMessage: nil)
    }

    func getStatuses() {
        //        NCUtility().getUserStatus(userIcon: <#T##String?#>, userStatus: <#T##String?#>, userMessage: <#T##String?#>)
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
            let result = await NextcloudKit.shared.setUserStatusAsync(status: selectedStatus ?? "", account: account) { task in
                Task {
                    let identifier = await NCNetworking.shared.networkingTasks.createIdentifier(account: self.account,
                                                                                                name: "setUserStatus")
                    await NCNetworking.shared.networkingTasks.track(identifier: identifier, task: task)
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
