// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Iva Horn
// SPDX-License-Identifier: GPL-3.0-or-later

///
/// The schema for the `downloadlimit` capability response model embedded in ``CapabilitiesResponse``.
///
struct DownloadLimitCapabilityResponse: Decodable {
    ///
    /// The download capability is enabled.
    ///
    let enabled: Bool
}
