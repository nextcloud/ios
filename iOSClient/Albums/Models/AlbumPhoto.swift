// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

// Album metadata is kept in memory; its DAV path must not replace the original file in Realm.
struct AlbumPhoto: Identifiable {
    let metadata: tableMetadata
    let albumFileName: String

    var id: String { metadata.fileId }
}
