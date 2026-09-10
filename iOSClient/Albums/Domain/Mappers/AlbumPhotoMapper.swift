// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

extension AlbumPhotoDTO {
    func toAlbumPhoto() -> AlbumPhoto {
        return AlbumPhoto(
            id: self.fileId,
            fileName: self.fileName,
            contentType: self.contentType,
            contentLength: self.contentLength,
            lastModified: self.lastModified,
            hasPreview: self.hasPreview,
            isHidden: self.isHidden,
            isFavorite: self.isFavorite,
            permissions: self.permissions,
            originalDateTime: self.originalDateTime,
            width: self.width,
            height: self.height
        )
    }
}

extension Sequence where Element == AlbumPhotoDTO {
    func toAlbumPhotos() -> [AlbumPhoto] { map { $0.toAlbumPhoto() } }
}
