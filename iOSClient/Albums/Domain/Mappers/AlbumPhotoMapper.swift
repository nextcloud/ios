//
//  AlbumPhotoMapper.swift
//  Nextcloud
//
//  Created by Dhanesh on 28/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

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
