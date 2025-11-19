// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

@Observable class NCUserStatusModel {
    struct UserStatus: Hashable {
        let names: [String] // should be array
        let titleKey: String
    }

    @ObservationIgnored let userStatuses: [UserStatus] = [
        .init(names: ["online"], titleKey: "_online_"),
        .init(names: ["away"], titleKey: "_away_"),
        .init(names: ["busy"], titleKey: "_busy_"),
        .init(names: ["dnd"], titleKey: "_dnd_"),
        .init(names: ["invisible", "offline"], titleKey: "_invisible_")
    ]

    var selectedStatus: String?

    @ObservationIgnored let account: String

    init(account: String) {
        self.account = account
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
}
