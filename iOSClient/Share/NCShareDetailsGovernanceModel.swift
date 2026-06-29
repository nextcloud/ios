// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

enum GovernanceViewState {
    case loading
    case selectedLabelsUpdated(entityLabels: NKGovernanceEntityLabels, availableSensitivityLabels: [NKGovernanceLabel], availableRetentionLabels: [NKGovernanceLabel])
    case error(Error)
}

@MainActor
@Observable
final class NCShareDetailsGovernanceModel {
    private(set) var sensitivityLabels: [NKGovernanceLabel] = []
    private(set) var retentionLabels: [NKGovernanceLabel] = []
//    private(set) var isLoading = false

    var state: GovernanceViewState = .loading

    var selectedSensitivityLabelID = ""
    var selectedRetentionLabelID = ""

    private var appliedSensitivityLabelID = ""
    private var appliedRetentionLabelID = ""

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

        sensitivityLabels = await sensitivity.labels ?? []
        retentionLabels = await retention.labels ?? []

        guard let entityLabels = await entity.labels,
        let sensitivityLabels = await sensitivity.labels,
        let retentionLabels = await retention.labels
        else { return }
//        appliedSensitivityLabelID = entityLabels?.sensitivity?.id ?? ""
//        appliedRetentionLabelID = entityLabels?.retention.first?.id ?? ""
//        selectedSensitivityLabelID = appliedSensitivityLabelID
//        selectedRetentionLabelID = appliedRetentionLabelID

        state = .selectedLabelsUpdated(entityLabels: entityLabels, availableSensitivityLabels: sensitivityLabels, availableRetentionLabels: retentionLabels)
    }

    func applySensitivityLabel(_ id: String) async {
        guard id != appliedSensitivityLabelID else { return }

        if await applyLabel(type: .sensitivity, newID: id, appliedID: appliedSensitivityLabelID) {
            appliedSensitivityLabelID = id
        } else {
            selectedSensitivityLabelID = appliedSensitivityLabelID
        }
    }

    func applyRetentionLabel(_ id: String) async {
        guard id != appliedRetentionLabelID else { return }

        if await applyLabel(type: .retention, newID: id, appliedID: appliedRetentionLabelID) {
            appliedRetentionLabelID = id
        } else {
            selectedRetentionLabelID = appliedRetentionLabelID
        }
    }

    private func applyLabel(type: NKGovernanceLabelType, newID: String, appliedID: String) async -> Bool {
        if newID.isEmpty {
            return await NextcloudKit.shared.removeGovernanceLabel(entityId: entityID, labelType: type, labelId: appliedID, account: account).error == .success
        }

        return await NextcloudKit.shared.setGovernanceLabel(entityId: entityID, labelType: type, labelId: newID, account: account).error == .success
    }
}
