// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

struct GovernanceData {
    let availableSensitivityLabels: [NKGovernanceLabel]
    let availableRetentionLabels: [NKGovernanceLabel]
    let availableHoldLabels: [NKGovernanceLabel]
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
    var selectedRetentionLabelIDs: Set<String> = []
    var selectedHoldLabelIDs: Set<String> = []

    private let metadata: tableMetadata

    init(metadata: tableMetadata) {
        self.metadata = metadata
    }

    var account: String { metadata.account }

    private var entityID: String { metadata.fileId }

    func load() async {
        async let sensitivity = NextcloudKit.shared.getGovernanceAvailableSensitivityLabels(entityId: entityID, account: account)
        async let retention = NextcloudKit.shared.getGovernanceAvailableRetentionLabels(entityId: entityID, account: account)
        async let hold = NextcloudKit.shared.getGovernanceAvailableHoldLabels(entityId: entityID, account: account)
        async let entity = NextcloudKit.shared.getGovernanceLabels(entityId: entityID, account: account)

        guard let entityLabels = await entity.labels,
              let sensitivityLabels = await sensitivity.labels,
              let retentionLabels = await retention.labels,
              let holdLabels = await hold.labels
        else { return }

        selectedSensitivityLabelID = entityLabels.sensitivity?.id ?? ""
        selectedRetentionLabelIDs = Set(entityLabels.retention.map(\.id))
        // NKGovernanceEntityLabels exposes no hold, so applied holds can't be preselected.

        state = .loaded(GovernanceData(
            availableSensitivityLabels: sensitivityLabels,
            availableRetentionLabels: retentionLabels,
            availableHoldLabels: holdLabels
        ))
    }

    func applySensitivityLabel(from oldID: String, to newID: String) async {
        await applyLabel(type: .sensitivity, oldID: oldID, newID: newID)
    }

    /// Persists a multi-selection by diffing against what's applied and calling set/remove per changed label.
    func saveLabels(type: NKGovernanceLabelType, selectedIDs: Set<String>) async {
        let current = (type == .retention) ? selectedRetentionLabelIDs : selectedHoldLabelIDs

        for id in selectedIDs.subtracting(current) {
            await applyLabel(type: type, oldID: "", newID: id)
        }

        for id in current.subtracting(selectedIDs) {
            await applyLabel(type: type, oldID: id, newID: "")
        }

        if type == .retention {
            selectedRetentionLabelIDs = selectedIDs
        } else {
            selectedHoldLabelIDs = selectedIDs
        }
    }

    private func applyLabel(type: NKGovernanceLabelType, oldID: String, newID: String) async {
        if newID.isEmpty {
            _ = await NextcloudKit.shared.removeGovernanceLabel(entityId: entityID, labelType: type, labelId: oldID, account: account)
        } else {
            _ = await NextcloudKit.shared.setGovernanceLabel(entityId: entityID, labelType: type, labelId: newID, account: account)
        }
    }
}
