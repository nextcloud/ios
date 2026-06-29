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
        Form {
            Section(header:
                Text(NSLocalizedString("_governance_", comment: "")).font(.headline)
            ) {
                labelPicker(
                    title: "_sensitivity_label_",
                    labels: model.sensitivityLabels,
                    selection: $model.selectedSensitivityLabelID
                ) { newValue in
                    await model.applySensitivityLabel(newValue)
                }

                labelPicker(
                    title: "_file_retention_",
                    labels: model.retentionLabels,
                    selection: $model.selectedRetentionLabelID
                ) { newValue in
                    await model.applyRetentionLabel(newValue)
                }
            }
        }
        .tint(Color(NCBrandColor.shared.getElement(account: model.account)))
        .task {
            await model.load()
        }
    }

    private func labelPicker(
        title: String,
        labels: [NKGovernanceLabel],
        selection: Binding<String>,
        onChange: @escaping (String) async -> Void
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
        .onChange(of: selection.wrappedValue) { _, newValue in
            Task { await onChange(newValue) }
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
