//
//  Album.swift
//  Nextcloud
//
//  Created by Dhanesh on 26/08/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

public struct Album: Identifiable, Hashable {
    
    public let id: String
    let href: String
    let name: String
    let lastPhotoId: String?
    let itemCount: Int?
    let location: String?
    let dateRange: String?
    let collaborators: String?
    let startDate: Date?
    let endDate: Date?

    struct AlbumDateRange: Codable, Hashable {
        let start: TimeInterval
        let end: TimeInterval
    }
    
    init(
        href: String,
        lastPhotoId: String?,
        itemCount: Int?,
        location: String?,
        dateRange: String?,
        collaborators: String?
    ) {
        self.id = href
        self.href = href
        
        if let lastComponent = href.split(separator: "/").last {
            self.name = lastComponent.removingPercentEncoding ?? String(lastComponent)
        } else {
            self.name = href
        }
        
        self.lastPhotoId = lastPhotoId
        self.itemCount = itemCount
        self.location = location
        self.dateRange = dateRange
        self.collaborators = collaborators
        
        if let dateRange = dateRange?.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(AlbumDateRange.self, from: dateRange) {
            self.startDate = Date(timeIntervalSince1970: decoded.start)
            self.endDate   = Date(timeIntervalSince1970: decoded.end)
        } else {
            // FALLBACK: Use current date for new/empty albums
            let now = Date()
            self.startDate = now
            self.endDate   = now
        }
    }
}
