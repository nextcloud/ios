// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

extension AlbumDTO {
    func toAlbum() -> Album {
        return Album(
            href: self.href,
            lastPhotoId: self.lastPhotoId,
            itemCount: self.itemCount,
            location: self.location,
            dateRange: self.dateRange,
            collaborators: self.collaborators
        )
    }
}

extension Sequence where Element == AlbumDTO {
    func toAlbums() -> [Album] { map { $0.toAlbum() } }
}
