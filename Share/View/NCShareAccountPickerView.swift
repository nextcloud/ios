// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

@MainActor
struct NCShareAccountPickerView: View {
    @ObservedObject var model: NCShareViewModel

    var body: some View {
        NavigationStack {
            List(model.accounts) { account in
                Button {
                    model.selectAccount(account.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: account.name)
                                .foregroundStyle(.primary)
                            Text(verbatim: account.user)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(verbatim: account.serverUrl)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if account.isSelected {
                            Image(systemName: "checkmark")
                                .accessibilityHidden(true)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(account.isSelected ? .isSelected : [])
            }
            .navigationTitle(NSLocalizedString("_account_select_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("_cancel_", comment: "")) { model.dismissAccountPicker() }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Accounts") {
    NCShareAccountPickerView(model: .preview())
        .allowsHitTesting(false)
}
#endif
