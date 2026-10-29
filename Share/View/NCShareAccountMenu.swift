// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareAccountMenu: View {
    @ObservedObject var model: NCShareViewModel

    var body: some View {
        Menu {
            Picker(NSLocalizedString("_account_select_", comment: ""), selection: Binding(
                get: { model.accounts.first(where: \.isSelected)?.id ?? "" },
                set: { model.selectAccount($0) }
            )) {
                ForEach(model.accounts) { account in
                    Label {
                        Text(verbatim: account.name)
                        Text(verbatim: account.user + " · " + account.serverUrl)
                    } icon: {
                        avatar(for: account.id)
                    }
                    .tag(account.id)
                }
            }
            .pickerStyle(.inline)
        } label: {
            HStack(spacing: 8) {
                avatar(for: model.accounts.first(where: \.isSelected)?.id ?? "")
                Text(verbatim: model.accountName)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(model.accounts.count < 2)

    }

    @ViewBuilder
    private func avatar(for account: String) -> some View {
        if let image = model.accountAvatars[account] {
            Image(uiImage: image)
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle")
        }
    }
}

#if DEBUG && SHARE_PREVIEWS
#Preview("Accounts") {
    NavigationStack {
        Text("Share")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NCShareAccountMenu(model: .preview())
                }
            }
    }
}
#endif
