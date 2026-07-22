// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

/// Reusable selection sheet for a governance label type.
/// Single-select (sensitivity, with a "None" row) or multi-select (retention / hold);
/// holds the selection transiently and reports the chosen set on Save.
struct NCGovernanceLabelSelectorView: View {
    let title: String
    let labels: [NKGovernanceLabel]
    let account: String
    let allowsMultipleSelection: Bool
    let onSave: (Set<String>) async -> Void

    @State private var selected: Set<String>
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        labels: [NKGovernanceLabel],
        account: String,
        allowsMultipleSelection: Bool = true,
        initialSelection: Set<String>,
        onSave: @escaping (Set<String>) async -> Void
    ) {
        self.title = title
        self.labels = labels
        self.account = account
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onSave = onSave
        _selected = State(initialValue: initialSelection)
    }

    var body: some View {
        NavigationStack {
            List {
                if !allowsMultipleSelection {
                    noneRow
                }

                ForEach(labels, id: \.id) { label in
                    Button {
                        toggle(label.id)
                    } label: {
                        row(dot: label.displayColor, name: label.name, isSelected: selected.contains(label.id))
                    }
                }
            }
            .navigationTitle(NSLocalizedString(title, comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("_cancel_", comment: ""), systemImage: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("_save_", comment: ""), systemImage: "checkmark") {
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

    private var noneRow: some View {
        Button {
            selected = []
        } label: {
            row(dot: .clear, name: NSLocalizedString("_none_", comment: ""), isSelected: selected.isEmpty)
        }
    }

    private func row(dot: Color, name: String, isSelected: Bool) -> some View {
        HStack {
            Circle()
                .fill(dot)
                .frame(width: 10, height: 10)

            Text(name)
                .foregroundStyle(Color.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(Color(NCBrandColor.shared.getElement(account: account)))
            }
        }
    }

    private func toggle(_ id: String) {
        if !allowsMultipleSelection {
            selected = [id]
            return
        }

        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

extension NKGovernanceLabel {
    var displayColor: Color {
        if let color = UIColor(hex: color) {
            return Color(color)
        }

        return .secondary
    }
}
