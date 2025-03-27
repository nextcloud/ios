// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// Capability response for a given capability..
///
struct CapabilityResponse: Decodable {
    ///
    /// The download capability is enabled.
    ///
    let enabled: Bool
}
