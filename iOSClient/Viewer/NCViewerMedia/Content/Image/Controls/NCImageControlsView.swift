// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Normal thumbnail overlay. Navigation and the information sheet remain in the hosting controller.
struct NCImageControlsView: View {
    @ObservedObject var model: NCMediaViewerModel

    var body: some View {
        if !model.isChromeHidden, model.numberOfPages > 1 {
            NCMediaViewerThumbnail(
                selectedIndex: model.selectedIndex,
                numberOfPages: model.numberOfPages,
                reloadRevision: model.thumbnailReloadRevision,
                metadataProvider: { index in
                    model.metadataForThumbnail(at: index)
                },
                metadataResolver: { index in
                    await model.resolveMetadataForThumbnail(at: index)
                },
                previewURLProvider: { metadata in
                    await model.previewURL(
                        for: metadata,
                        ext: NCGlobal.shared.previewExt256
                    )
                },
                audioLoadProvider: { index in
                    await model.loadPageIfNeeded(index: index)
                },
                isDeletedProvider: { index in
                    model.isThumbnailDeleted(at: index)
                },
                onSelect: { index in
                    Task {
                        await model.displayPreviewPage(at: index)
                    }
                }
            )
            .equatable()
            .frame(height: NCMediaViewerThumbnail.preferredHeight)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
            .zIndex(10)
        }
    }
}
