// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

struct AlbumPhoto: Identifiable, Hashable {
    public let id: String
    let fileName: String
    let contentType: String
    let contentLength: Int
    let lastModified: Date
    let hasPreview: Bool
    let isHidden: Bool
    let isFavorite: Bool
    let permissions: String
    let originalDateTime: Date?
    let width: Int?
    let height: Int?
}
