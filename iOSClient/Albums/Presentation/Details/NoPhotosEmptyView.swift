// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Dhanesh
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NoPhotosEmptyView: View {
    let onAddPhotosIntent: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    Image(systemName: "photo.stack.fill")
                        .resizable()
                        .scaledToFit()
                    // NCBrandColor.shared.getElement(account: session.account)]
                        .foregroundStyle(Color(NCBrandColor.shared.customer))
                        .frame(maxWidth: .infinity, maxHeight: 75)
                        .padding(.bottom, 30)

                    VStack(alignment: .center, spacing: 16) {
                        Text(NSLocalizedString("_albums_photos_empty_heading_", comment: ""))
                            .cappedFont(.headline, maxDynamicType: .accessibility2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(NSLocalizedString("_albums_photos_empty_subheading_", comment: ""))
                            .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Button(action: onAddPhotosIntent) {
                            Label(
                                NSLocalizedString(
                                    "_albums_photos_empty_add_photos_btn_",
                                    comment: ""
                                ),
                                systemImage: "plus"
                            )
                            .cappedFont(.subheadline, maxDynamicType: .accessibility1)
                            .foregroundStyle(Color(NCBrandColor.shared.customer))
                            .multilineTextAlignment(.center)
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
#Preview {
    NavigationView {
        NoPhotosEmptyView(
            onAddPhotosIntent: {}
        )
        .navigationTitle("Album")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
