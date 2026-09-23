// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

// Album membership resolves the original metadata by ocId.
struct AlbumPhoto: Identifiable {
    let metadata: tableMetadata

    var id: String { metadata.fileId }
}
