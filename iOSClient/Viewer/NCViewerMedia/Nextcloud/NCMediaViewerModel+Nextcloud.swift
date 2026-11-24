// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension NCMediaViewerModel {
    convenience init(
        currentMetadata: tableMetadata,
        ocIds: [String],
        session: NCSession.Session,
        loader: NCMediaViewerLoader,
        loadingPolicy: NCMediaViewerLoadingPolicy = .standard
    ) {
        self.init(currentMetadata: loader.item(from: currentMetadata), ocIds: ocIds,
                  session: session, loader: loader, loadingPolicy: loadingPolicy)
    }

    /// App integration only: actions must receive the complete original record.
    func appMetadata(for item: NCMediaViewerItem) -> tableMetadata? {
        (loader as? NCMediaViewerLoader)?.appMetadata(for: item)
    }

    func viewerItem(from metadata: tableMetadata) -> NCMediaViewerItem {
        if let loader = loader as? NCMediaViewerLoader {
            return loader.item(from: metadata)
        }
        return NCMediaViewerItem(metadata: metadata)
    }
}
