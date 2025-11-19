// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCUserStatusView: View {
    let account: String

//    @State private var selectedItem: String?
    @State private var model: NCUserStatusModel

    init(account: String) {
        self.account = account
        model = NCUserStatusModel(account: account)
    }

    var body: some View {
            List {
                ForEach(model.userStatuses, id: \.self) { item in
                    HStack {
                        let status = model.getStatusDetails(name: item.names.first!)

                        Image(uiImage: status.statusImage ?? UIImage())
                            .renderingMode(.template)
                            .resizable()
                            .foregroundStyle(Color(status.statusImageColor))
                            .frame(width: 20, height: 20)
                            .padding(.trailing, 8)
                        Text(NSLocalizedString(item.titleKey, comment: ""))
                        Spacer()
                        if model.selectedStatus == item.names.first {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle()) // make the whole row tappable
                    .onTapGesture {
                        let firstStatus = item.names.first!
                        model.selectedStatus = (model.selectedStatus == firstStatus) ? nil : firstStatus
                        model.setStatus(account: account)
                    }
                }
            }
        .navigationTitle(NSLocalizedString("_select_user_status_", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            model.getStatus(account: account)
        }
    }
}

#Preview {
    NavigationStack {
        NCUserStatusView(account: "demo@example.com")
    }
}
