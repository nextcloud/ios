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
    case error
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
        let result = await NextcloudKit.shared.getGovernanceAvailableLabels(entityId: entityID, account: account)

        guard let labels = result.labels else {
            nkLog(error: "Could not load governance labels: \(result.error.errorDescription) (\(result.error.errorCode))")
            state = .error
            return
        }

        selectedSensitivityLabelID = labels.sensitivity.first(where: \.isAssigned)?.id ?? ""
        selectedRetentionLabelIDs = Set(labels.retention.filter(\.isAssigned).map(\.id))
        selectedHoldLabelIDs = Set(labels.hold.filter(\.isAssigned).map(\.id))

        state = .loaded(GovernanceData(
            availableSensitivityLabels: labels.sensitivity,
            availableRetentionLabels: labels.retention,
            availableHoldLabels: labels.hold
        ))
    }

    func applySensitivityLabel(from oldID: String, to newID: String) async {
        await applyLabel(type: .sensitivity, oldID: oldID, newID: newID)
        selectedSensitivityLabelID = newID
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
