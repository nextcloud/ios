// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

// MARK: - Media Viewer View

/// Main SwiftUI media viewer.
struct NCMediaViewerView: View {
    @StateObject private var model: NCMediaViewerModel
    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
    let onClose: (_ ocId: String?) -> Void

    /// Creates the media viewer view.
    init(
        model: NCMediaViewerModel,
        contextMenuController: NCMainTabBarController? = nil,
        navigationBar: UINavigationBar? = nil,
        onVisibleMetadataChanged: @escaping (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void = { _, _ in },
        onClose: @escaping (_ ocId: String?) -> Void = { _ in }
    ) {
        _model = StateObject(wrappedValue: model)
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.onVisibleMetadataChanged = onVisibleMetadataChanged
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Color.ncViewerBackground(.system)
                .ignoresSafeArea()

            NCMediaViewerPagingView(
                model: model,
                contextMenuController: contextMenuController,
                navigationBar: navigationBar,
                onVisibleMetadataChanged: onVisibleMetadataChanged,
                onClose: onClose
            )
            .ignoresSafeArea()
        }
        .background(Color.ncViewerBackground(.system))
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task {
            await model.loadSelectedPageIfNeeded()
        }
    }
}

// MARK: - Media Viewer Preview

#if DEBUG
import NextcloudKit

#Preview("Media Viewer - Light") {
    NCMediaViewerView.previewView()
        .preferredColorScheme(.light)
}

#Preview("Media Viewer - Dark") {
    NCMediaViewerView.previewView()
        .preferredColorScheme(.dark)
}

private extension NCMediaViewerView {
    static func previewView() -> some View {
        let metadata = tableMetadata()
        metadata.ocId = "preview-ocid"
        metadata.fileName = "preview.jpg"
        metadata.fileNameView = "preview.jpg"
        metadata.classFile = NKTypeClassFile.image.rawValue

        let model = NCMediaViewerModel(
            currentMetadata: metadata.detachedCopy(),
            ocIds: [
                metadata.ocId
            ],
            session: NCSession().getSession(account: ""),
            mediaSearch: false,
            loader: NCMediaViewerLoader()
        )

        return NCMediaViewerView(model: model)
    }
}
#endif
