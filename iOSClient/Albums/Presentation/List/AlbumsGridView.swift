// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import Foundation
import UIKit

struct AlbumsGridView: View {
    @Environment(\.localAccount) var localAccount: String
    let albums: [Album]
    let onAlbumClicked: (Album) -> Void

    private func columnCount(for width: CGFloat) -> Int {
        width >= 600 ? 3 : 2
    }

    private func columns(count: Int) -> [GridItem] {
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: count)
    }

    var body: some View {
        GeometryReader { geometry in
            let columnCount = columnCount(for: geometry.size.width)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(NSLocalizedString("_albums_list_own_albums_heading_", comment: ""))
                        .font(.system(size: 21, weight: .bold))

                    LazyVGrid(columns: columns(count: columnCount), spacing: 20) {
                        ForEach(albums, id: \.id) { album in
                            Button {
                                onAlbumClicked(album)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    AlbumGridItemView(album: album)

                                    Text(album.name)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let subtitle = makeSubtitle(for: album), !subtitle.isEmpty {
                                        Text(subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(UIColor.systemGray))
                                            .lineLimit(2, reservesSpace: true)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    private func makeSubtitle(for album: Album) -> String? {
        guard let count = album.itemCount else { return nil }
        var parts: [String] = []
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")

        if count > 0, let end = album.endDate {
            if let start = album.startDate,
               !Calendar.current.isDate(start, equalTo: end, toGranularity: .month) {
                parts.append(
                    String.localizedStringWithFormat(
                        NSLocalizedString("_albums_list_date_range_", comment: ""),
                        formatter.string(from: start),
                        formatter.string(from: end)
                    )
                )
            } else {
                parts.append(formatter.string(from: end))
            }
        } else if count == 0, let created = album.startDate {
            parts.append(formatter.string(from: created))
        }

        parts.append(
            String.localizedStringWithFormat(
                NSLocalizedString("_albums_list_photos_and_videos_count_", comment: ""),
                count
            )
        )
        return parts.joined(separator: " · ")
    }
}

// #if DEBUG
// #Preview {
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
// }
// #endif
