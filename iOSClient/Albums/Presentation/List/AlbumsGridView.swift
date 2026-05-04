//
//  AlbumsGridView.swift
//  Nextcloud
//
//  Created by Dhanesh on 28/07/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import Foundation
import UIKit

struct AlbumsGridView: View {
    
    @Environment(\.localAccount) var localAccount: String
    
    let albums: [Album]
    
    let onAlbumClicked: (Album) -> Void
    
//    private let columns = [
//        GridItem(.flexible(), spacing: 16),
//        GridItem(.flexible(), spacing: 16)
//    ]
//     Use this inside AlbumsGridView to detect iPad
    private var columns: [GridItem] {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let count = isIPad ? 3 : 2 // 4 columns for iPad, 2 for iPhone
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    // Logic translated from your buildMediaPhotoVideo function
    private var iconPointSize: CGFloat {
        let count = columns.count
        switch count {
        case 0...1: return 60
        case 2...3: return 30
        case 4...5: return 25
        default:    return 20
        }
    }

    var body: some View {
        
        ScrollView {
            
            VStack(alignment: .leading, spacing: 16) {
                
                Text(NSLocalizedString("_albums_list_own_albums_heading_", comment: ""))
                    .font(.system(size: 21, weight: .bold))
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(albums, id: \.id) { album in
                        Button {
                            onAlbumClicked(album)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                
//                                AlbumGridItemView(album: album)
                                AlbumGridItemView(album: album, iconSize: iconPointSize)

                                Text(album.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let subtitle = makeSubtitle(for: album), !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.system(size: 13))
                                        .foregroundColor(Color(UIColor.systemGray))
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private func makeSubtitle(for album: Album) -> String? {
        guard let count = album.itemCount else { return nil }
        var parts: [String] = ["\(count) \(NSLocalizedString("_albums_list_entities_", comment: ""))"]
        let formatter = DateFormatter()
        if count > 0, let end = album.endDate {
            formatter.dateStyle = .medium
            parts.append(formatter.string(from: end))
        } else if count == 0, let created = album.startDate {
            formatter.dateFormat = "MMMM yyyy" // "MMMM" for full month name, "yyyy" for year
            parts.append(formatter.string(from: created))
        }
        return parts.joined(separator: " - ")
    }
}

//#if DEBUG
//#Preview {
//    AlbumsGridView(
//        albums: [
//            Album(
//                href: "/Geburtstagsalbum",
//                lastPhotoId: "birthday",
//                itemCount: 16,
//                location: "Berlin",
//                dateRange: "Feb 2022",
//                collaborators: "Anna, John"
//            ),
//            Album(
//                href: "/Urlaub",
//                lastPhotoId: "mountain",
//                itemCount: 42,
//                location: "Alps",
//                dateRange: nil,
//                collaborators: nil
//            ),
//            Album(
//                href: "/Office Party",
//                lastPhotoId: "-1",
//                itemCount: 0,
//                location: nil,
//                dateRange: "Dec 2023",
//                collaborators: nil
//            )
//        ],
//        onAlbumClicked: { _ in}
//    )
//}
//#endif

