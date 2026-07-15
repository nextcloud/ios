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
        case sensitivity
        case retention
        case hold

        var id: String { rawValue }

        var title: String {
            switch self {
            case .sensitivity: return "_sensitivity_label_"
            case .retention: return "_file_retention_"
            case .hold: return "_legal_hold_"
            }
        }
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
                            labelSelectorRow(
                                title: "_sensitivity_label_",
                                labels: data.availableSensitivityLabels,
                                selectedIDs: sensitivitySelection
                            ) {
                                activeSelector = .sensitivity
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
                        selectorSheet(selector, data: data)
                    }

                case .error(let error):
                    Text(error.localizedDescription)
            }
        }
        .task {
            await model.load()
        }
    }

    private var sensitivitySelection: Set<String> {
        model.selectedSensitivityLabelID.isEmpty ? [] : [model.selectedSensitivityLabelID]
    }

    private func selectorSheet(_ selector: GovernanceSelector, data: GovernanceData) -> some View {
        let labels: [NKGovernanceLabel]
        let initialSelection: Set<String>

        switch selector {
        case .sensitivity:
            labels = data.availableSensitivityLabels
            initialSelection = sensitivitySelection
        case .retention:
            labels = data.availableRetentionLabels
            initialSelection = model.selectedRetentionLabelIDs
        case .hold:
            labels = data.availableHoldLabels
            initialSelection = model.selectedHoldLabelIDs
        }

        return NCGovernanceLabelSelectorView(
            title: selector.title,
            labels: labels,
            account: model.account,
            allowsMultipleSelection: selector != .sensitivity,
            initialSelection: initialSelection
        ) { newSelection in
            await save(selector, newSelection: newSelection)
        }
        .presentationDetents([.medium, .large])
    }

    private func save(_ selector: GovernanceSelector, newSelection: Set<String>) async {
        switch selector {
        case .sensitivity:
            await model.applySensitivityLabel(from: model.selectedSensitivityLabelID, to: newSelection.first ?? "")
        case .retention:
            await model.saveLabels(type: .retention, selectedIDs: newSelection)
        case .hold:
            await model.saveLabels(type: .hold, selectedIDs: newSelection)
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
