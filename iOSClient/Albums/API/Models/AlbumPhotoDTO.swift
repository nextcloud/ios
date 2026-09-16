// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-License-Identifier: GPL-3.0-or-later

public struct AlbumPhotoDTO {
    let fileId: String
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
