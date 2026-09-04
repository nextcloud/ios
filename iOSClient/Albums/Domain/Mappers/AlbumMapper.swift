//
//  AlbumMapper.swift
//  Nextcloud
//
//  Created by Dhanesh on 28/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

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
