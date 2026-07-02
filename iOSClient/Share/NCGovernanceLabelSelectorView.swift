// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

/// Reusable multi-select sheet for a governance label type (retention / hold).
/// Holds the selection transiently and reports the chosen set on Save.
struct NCGovernanceLabelSelectorView: View {
    let title: String
    let labels: [NKGovernanceLabel]
    let account: String
    let onSave: (Set<String>) async -> Void

    @State private var selected: Set<String>
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        labels: [NKGovernanceLabel],
        account: String,
        initialSelection: Set<String>,
        onSave: @escaping (Set<String>) async -> Void
    ) {
        self.title = title
        self.labels = labels
        self.account = account
        self.onSave = onSave
        _selected = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(labels, id: \.id) { label in
                    Button {
                        toggle(label.id)
                    } label: {
                        HStack {
                            Circle()
                                .fill(color(for: label))
                                .frame(width: 10, height: 10)

                            Text(label.name)
                                .foregroundStyle(.primary)

                            Spacer()

                            if selected.contains(label.id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(NCBrandColor.shared.getElement(account: account)))
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString(title, comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("_cancel_", comment: "")) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("_save_", comment: "")) {
                        Task {
                            isSaving = true
                            await onSave(selected)
                            isSaving = false
                            dismiss()
                        }
                    }
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
            .disabled(isSaving)
            .tint(Color(NCBrandColor.shared.getElement(account: account)))
        }
    }

    private func toggle(_ id: String) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func color(for label: NKGovernanceLabel) -> Color {
        if let color = UIColor(hex: label.color) {
            return Color(color)
        }

        return .secondary
    }
}
