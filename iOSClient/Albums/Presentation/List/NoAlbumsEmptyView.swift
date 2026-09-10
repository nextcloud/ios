// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NoAlbumsEmptyView: View {
    let onNewAlbumCreationIntent: () -> Void
    @Environment(\.localAccount) var localAccount: String

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image(systemName: "photo.stack.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(
                            Color(NCBrandColor.shared.getElement(account: localAccount))
                        )
                        .frame(maxWidth: .infinity, maxHeight: 75)
                        .padding(.bottom, 30)

                    VStack(alignment: .center, spacing: 16) {
                        Text(NSLocalizedString("_albums_list_empty_heading_", comment: ""))
                            .cappedFont(.headline, maxDynamicType: .accessibility2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(NSLocalizedString("_albums_list_empty_subheading_", comment: ""))
                            .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Button(action: onNewAlbumCreationIntent) {
                            Label(
                                NSLocalizedString(
                                    "_albums_list_empty_new_album_btn_",
                                    comment: ""
                                ),
                                systemImage: "plus"
                            )
                            .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                            .foregroundStyle(
                                Color(NCBrandColor.shared.getElement(account: localAccount))
                            )
                        }
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 0)
                }
                .frame(
                    maxWidth: .infinity,
                    minHeight: geometry.size.height
                )
            }
        }
    }
}

#if DEBUG
struct NoAlbumsEmptyView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            NoAlbumsEmptyView(
                onNewAlbumCreationIntent: {}
            )
            .navigationTitle("Albums")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
