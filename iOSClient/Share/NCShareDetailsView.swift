// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

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
                HStack {
                    Text(NSLocalizedString("_sensitivity_label_", comment: ""))
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                    Spacer()
                    Picker("", selection: $model.selectedSensitivityLabel) {
                        ForEach(model.getSensitivityLabels()) { label in
                            Label(label.localizedName, systemImage: label.systemImageName).tag(label)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .onChange(of: model.selectedSensitivityLabel) { _, newValue in
                    model.setSensitivityLabel(newValue)
                }

                HStack {
                    Text(NSLocalizedString("_file_retention_", comment: ""))
                        .cappedFont(.body, maxDynamicType: .accessibility2)
                    Spacer()
                    Picker("", selection: $model.selectedRetentionPolicy) {
                        ForEach(model.getRetentionPolicies()) { policy in
                            Label(policy.localizedName, systemImage: policy.systemImageName).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .onChange(of: model.selectedRetentionPolicy) { _, newValue in
                    model.setRetentionPolicy(newValue)
                }
            }
        }
        .tint(Color(NCBrandColor.shared.getElement(account: model.account)))
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
