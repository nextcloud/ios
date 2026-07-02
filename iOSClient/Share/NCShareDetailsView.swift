// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

struct NCShareDetailsView: View {
    @State private var model: NCShareDetailsGovernanceModel
    @State private var activeSelector: GovernanceSelector?

    private enum GovernanceSelector: String, Identifiable {
        case retention
        case hold

        var id: String { rawValue }
    }

    init(metadata: tableMetadata) {
        _model = State(initialValue: NCShareDetailsGovernanceModel(metadata: metadata))
    }

    var body: some View {
        ZStack {
            switch model.state {
                case .loading:
                    Text("Loading")
                case .loaded(let data):
                    Form {
                        Section(header:
                                    Text(NSLocalizedString("_governance_", comment: "")).font(.headline)
                        ) {
                            labelPicker(
                                title: "_sensitivity_label_",
                                labels: data.availableSensitivityLabels,
                                selection: $model.selectedSensitivityLabelID
                            ) { oldValue, newValue in
                                await model.applySensitivityLabel(from: oldValue, to: newValue)
                            }

                            labelSelectorRow(
                                title: "_file_retention_",
                                labels: data.availableRetentionLabels,
                                selectedIDs: model.selectedRetentionLabelIDs
                            ) {
                                activeSelector = .retention
                            }

                            labelSelectorRow(
                                title: "_legal_hold_",
                                labels: data.availableHoldLabels,
                                selectedIDs: model.selectedHoldLabelIDs
                            ) {
                                activeSelector = .hold
                            }
                        }
                    }
                    .tint(Color(NCBrandColor.shared.getElement(account: model.account)))
                    .sheet(item: $activeSelector) { selector in
                        let isRetention = selector == .retention

                        NCGovernanceLabelSelectorView(
                            title: isRetention ? "_file_retention_" : "_legal_hold_",
                            labels: isRetention ? data.availableRetentionLabels : data.availableHoldLabels,
                            account: model.account,
                            initialSelection: isRetention ? model.selectedRetentionLabelIDs : model.selectedHoldLabelIDs
                        ) { newSelection in
                            await model.saveLabels(type: isRetention ? .retention : .hold, selectedIDs: newSelection)
                        }
                        .presentationDetents([.medium, .large])
                    }

                case .error(let error):
                    Text(error.localizedDescription)
            }
        }
        .task {
            await model.load()
        }
    }

    private func labelPicker(
        title: String,
        labels: [NKGovernanceLabel],
        selection: Binding<String>,
        onChange: @escaping (_ oldValue: String, _ newValue: String) async -> Void
    ) -> some View {
        HStack {
            Text(NSLocalizedString(title, comment: ""))
                .cappedFont(.body, maxDynamicType: .accessibility2)
            Spacer()
            Picker("", selection: selection) {
                Text(NSLocalizedString("_none_", comment: "")).tag("")
                ForEach(labels, id: \.id) { label in
                    Text(label.name).tag(label.id)
                }
            }
            .pickerStyle(.menu)
        }
        .onChange(of: selection.wrappedValue) { oldValue, newValue in
            Task { await onChange(oldValue, newValue) }
        }
    }

    private func labelSelectorRow(
        title: String,
        labels: [NKGovernanceLabel],
        selectedIDs: Set<String>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(NSLocalizedString(title, comment: ""))
                    .cappedFont(.body, maxDynamicType: .accessibility2)
                    .foregroundStyle(.primary)

                Spacer()

                Text(summary(labels: labels, selectedIDs: selectedIDs))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func summary(labels: [NKGovernanceLabel], selectedIDs: Set<String>) -> String {
        guard !selectedIDs.isEmpty else {
            return NSLocalizedString("_none_", comment: "")
        }

        return labels
            .filter { selectedIDs.contains($0.id) }
            .map(\.name)
            .joined(separator: ", ")
    }
}

final class NCShareDetailsViewController: UIHostingController<NCShareDetailsView>, NCSharePagingContent {
    var textField: UIView? { nil }
    var height: CGFloat = 0

    init(metadata: tableMetadata) {
        super.init(rootView: NCShareDetailsView(metadata: metadata))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }
}
