// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import NextcloudKit

extension NCNetworking {
    /// Applies per-file metadata returned by Nextcloud 34+ upload responses.
    ///
    /// Older servers do not return `X-NC-OwnerId` or `X-NC-Permissions` on upload responses, so this method keeps the
    /// existing locally-created metadata unchanged unless the connected server is new enough and the response values are non-empty.
    ///
    /// - Parameters:
    ///   - metadata: Local metadata row for the uploaded file.
    ///   - ownerId: Owner id parsed from the upload response.
    ///   - permissions: DAV permissions parsed from the upload response.
    func applyUploadResponse(to metadata: tableMetadata, ownerId: String?, permissions: String?) async {
        let capabilities: NKCapabilities.Capabilities
        if let cachedCapabilities = self.capabilities[metadata.account] {
            capabilities = cachedCapabilities
        } else {
            capabilities = await NKCapabilities.shared.getCapabilities(for: metadata.account)
        }
        guard NCBrandOptions.shared.isServerVersion(capabilities, greaterOrEqualTo: 34, 0, 0) else {
            return
        }

        if let ownerId, !ownerId.isEmpty {
            metadata.ownerId = ownerId
            if metadata.ownerDisplayName.isEmpty {
                metadata.ownerDisplayName = ownerId
            }
        }

        if let permissions, !permissions.isEmpty {
            metadata.permissions = permissions
        }
    }
}
