// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

struct NCShareDetailsView: View {
    @State private var model: NCShareDetailsGovernanceModel

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

                            labelPicker(
                                title: "_file_retention_",
                                labels: data.availableRetentionLabels,
                                selection: $model.selectedRetentionLabelID
                            ) { oldValue, newValue in
                                await model.applyRetentionLabel(from: oldValue, to: newValue)
                            }

                            labelPicker(
                                title: "_legal_hold_",
                                labels: data.availableHoldLabels,
                                selection: $model.selectedHoldLabelID
                            ) { oldValue, newValue in
                                await model.applyHoldLabel(from: oldValue, to: newValue)
                            }
                        }
                    }
                    .tint(Color(NCBrandColor.shared.getElement(account: model.account)))

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
