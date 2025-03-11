// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// A simplified interpretation of the capabilities response.
///
struct CapabilitiesResponse: Decodable {
    ///
    /// Sibling to a `version` object which is ignored as off writing.
    ///
    struct CapabilitiesResponseCapabilitiesComponent: Decodable {
        enum CodingKeys: String, CodingKey {
            case downloadLimit = "downloadlimit"
            case assistant = "assistant"
        }

        let downloadLimit: CapabilityResponse?
        let assistant: CapabilityResponse?
    }

    let capabilities: CapabilitiesResponseCapabilitiesComponent
}
