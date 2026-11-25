// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftUI

extension NCMediaViewerModel {
    convenience init(
        currentMetadata: tableMetadata,
        ocIds: [String],
        account: String,
        loader: NCMediaViewerLoader,
        loadingPolicy: NCMediaViewerLoadingPolicy = .app
    ) {
        self.init(currentMetadata: loader.item(from: currentMetadata), ocIds: ocIds,
                  account: account, loader: loader, loadingPolicy: loadingPolicy,
                  playbackProgressTint: { Color(NCBrandColor.shared.getElement(account: $0)) })
    }

    /// App integration only: actions must receive the complete original record.
    func appMetadata(for item: NCMediaViewerItem) -> tableMetadata? {
        ((loader as? NCMediaViewerLoader)?.services as? NCMediaViewerAppAdapter)?.appMetadata(for: item)
    }

    func viewerItem(from metadata: tableMetadata) -> NCMediaViewerItem {
        if let loader = loader as? NCMediaViewerLoader {
            return loader.item(from: metadata)
        }
        return NCMediaViewerItem(metadata: metadata)
    }
}

/// Default app wiring; other hosts supply their own NCMediaViewerServices.
extension NCMediaViewerLoader {
    convenience init() {
        self.init(services: NCMediaViewerAppAdapter())
    }

    func item(from metadata: tableMetadata) -> NCMediaViewerItem {
        if let services = services as? NCMediaViewerAppAdapter {
            return services.item(from: metadata)
        }
        return NCMediaViewerItem(metadata: metadata)
    }
}

/// App policy: neighboring originals download only on unmetered networks.
extension NCMediaViewerLoadingPolicy {
    static let app = NCMediaViewerLoadingPolicy(
        automaticallyDownloadsOriginalImages: true,
        automaticallyDownloadsLivePhotoResources: true,
        allowsNeighborOriginalDownloads: { NCMediaViewerNetworkMonitor.shared.isUnmetered }
    )
}
