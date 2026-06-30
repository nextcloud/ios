// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

struct GovernanceData {
    let availableSensitivityLabels: [NKGovernanceLabel]
    let availableRetentionLabels: [NKGovernanceLabel]
}

enum GovernanceViewState {
    case loading
    case loaded(GovernanceData)
    case error(Error)
}

@MainActor
@Observable
final class NCShareDetailsGovernanceModel {
    var state: GovernanceViewState = .loading

    var selectedSensitivityLabelID = ""
    var selectedRetentionLabelID = ""

    private let metadata: tableMetadata

    init(metadata: tableMetadata) {
        self.metadata = metadata
    }

    var account: String { metadata.account }

    private var entityID: String { metadata.fileId }

    func load() async {
        async let sensitivity = NextcloudKit.shared.getGovernanceAvailableSensitivityLabels(entityId: entityID, account: account)
        async let retention = NextcloudKit.shared.getGovernanceAvailableRetentionLabels(entityId: entityID, account: account)
        async let entity = NextcloudKit.shared.getGovernanceLabels(entityId: entityID, account: account)

        guard let entityLabels = await entity.labels,
              let sensitivityLabels = await sensitivity.labels,
              let retentionLabels = await retention.labels
        else { return }

        selectedSensitivityLabelID = entityLabels.sensitivity?.id ?? ""
        selectedRetentionLabelID = entityLabels.retention.first?.id ?? ""

        state = .loaded(GovernanceData(
            availableSensitivityLabels: sensitivityLabels,
            availableRetentionLabels: retentionLabels
        ))
    }

    func applySensitivityLabel(from oldID: String, to newID: String) async {
        await applyLabel(type: .sensitivity, oldID: oldID, newID: newID)
    }

    func applyRetentionLabel(from oldID: String, to newID: String) async {
        await applyLabel(type: .retention, oldID: oldID, newID: newID)
    }

    private func applyLabel(type: NKGovernanceLabelType, oldID: String, newID: String) async {
        if newID.isEmpty {
            _ = await NextcloudKit.shared.removeGovernanceLabel(entityId: entityID, labelType: type, labelId: oldID, account: account)
        } else {
            _ = await NextcloudKit.shared.setGovernanceLabel(entityId: entityID, labelType: type, labelId: newID, account: account)
        }
    }
}
