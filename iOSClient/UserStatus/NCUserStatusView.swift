// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCUserStatusView: View {
    let account: String

    @State private var model: NCUserStatusModel
    @Environment(\.dismiss) private var dismiss

    init(account: String) {
        self.account = account
        model = NCUserStatusModel(account: account)
    }

    var body: some View {
            List {
                ForEach(model.userStatuses, id: \.self) { item in
                    HStack {
                        let status = model.getStatusDetails(name: item.name)

                        Image(uiImage: status.statusImage ?? UIImage())
                            .renderingMode(.template)
                            .resizable()
                            .foregroundStyle(Color(status.statusImageColor))
                            .frame(width: 20, height: 20)
                        VStack(alignment: .leading) {
                            Text(NSLocalizedString(item.titleKey, comment: ""))

                            if !item.descriptionKey.isEmpty {
                                Text(NSLocalizedString(item.descriptionKey, comment: "")).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if model.selectedStatus == item.name {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle()) // make the whole row tappable
                    .onTapGesture {
                        model.selectedStatus = (model.selectedStatus == item.name) ? nil : item.name
                        model.setStatus(account: account)
                    }
                    .onChange(of: model.canDismiss) { _, newValue in
                        if newValue { dismiss() }
                    }
                }
            }
        .navigationTitle(NSLocalizedString("_select_user_status_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.getStatus(account: account)
        }
        .onDisappear {
            model.setAccountUserStatus(account: account)
        }
    }
}

#Preview {
    NavigationStack {
        NCUserStatusView(account: "demo@example.com")
    }
}
