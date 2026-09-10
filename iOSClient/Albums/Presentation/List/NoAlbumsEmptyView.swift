// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NoAlbumsEmptyView: View {

    let onNewAlbumCreationIntent: () -> Void

    private let contentPadding: CGFloat = 32.0

    var body: some View {

        ScrollView(.vertical) {

            VStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 96, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 220)

                VStack(alignment: .leading, spacing: 16) {

                    Text(NSLocalizedString("_albums_list_empty_heading_", comment: ""))
                        .font(.system(size: 48, weight: .bold))

                    Text(NSLocalizedString("_albums_list_empty_subheading_", comment: ""))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)

                    Button(action: onNewAlbumCreationIntent) {
                        Label(NSLocalizedString("_albums_list_empty_new_album_btn_", comment: ""), systemImage: "plus")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(NCBrandColor.shared.customer))
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, contentPadding)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, -20)
            }
        }
    }
}
