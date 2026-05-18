// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import NextcloudKit

@MainActor
@Observable
final class NCShareDetailsGovernanceModel {
    enum SensitivityLabel: String, CaseIterable, Identifiable {
        case publicLabel, internalUseOnly, restricted

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .publicLabel:     return NSLocalizedString("_public_", comment: "")
            case .internalUseOnly: return NSLocalizedString("_internal_use_only_", comment: "")
            case .restricted:      return NSLocalizedString("_restricted_", comment: "")
            }
        }

        var systemImageName: String {
            switch self {
            case .publicLabel:     return "link"
            case .internalUseOnly: return "person.2"
            case .restricted:      return "xmark"
            }
        }
    }

    enum RetentionPolicy: String, CaseIterable, Identifiable {
        case publicPolicy, internalUseOnly, restricted

        var id: String { rawValue }

        var localizedName: String {
            switch self {
            case .publicPolicy:    return NSLocalizedString("_public_", comment: "")
            case .internalUseOnly: return NSLocalizedString("_internal_use_only_", comment: "")
            case .restricted:      return NSLocalizedString("_restricted_", comment: "")
            }
        }

        var systemImageName: String {
            switch self {
            case .publicPolicy:    return "link"
            case .internalUseOnly: return "person.2"
            case .restricted:      return "xmark"
            }
        }
    }

    var selectedSensitivityLabel: SensitivityLabel = .publicLabel
    var selectedRetentionPolicy: RetentionPolicy = .publicPolicy

    private let metadata: tableMetadata

    init(metadata: tableMetadata) {
        self.metadata = metadata
    }

    var account: String { metadata.account }

    func getSensitivityLabels() -> [SensitivityLabel] {
        SensitivityLabel.allCases
    }

    func getRetentionPolicies() -> [RetentionPolicy] {
        RetentionPolicy.allCases
    }

    func setSensitivityLabel(_ label: SensitivityLabel) {
        selectedSensitivityLabel = label
    }

    func setRetentionPolicy(_ policy: RetentionPolicy) {
        selectedRetentionPolicy = policy
    }
}
