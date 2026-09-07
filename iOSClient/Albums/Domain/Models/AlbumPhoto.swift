//
//  AlbumPhoto.swift
//  Nextcloud
//
//  Created by Dhanesh on 28/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

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
