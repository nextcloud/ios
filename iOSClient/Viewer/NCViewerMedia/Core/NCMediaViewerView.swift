// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import NextcloudKit

// MARK: - Media Viewer View

/// Main SwiftUI media viewer.
struct NCMediaViewerView: View {
    @StateObject private var model: NCMediaViewerModel

    let contextMenuController: NCMainTabBarController?
    let navigationBar: UINavigationBar?
    let onVisibleMetadataChanged: (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void
    let onZoomChanged: (Bool) -> Void
    let onClose: (_ ocId: String?) -> Void
    let adaptiveControlsState: NCImageAdaptiveControlsState?
    let makeAdaptiveNavigationBar: (() -> UINavigationBar)?
    let onAdaptiveLayoutChanged: (Bool) -> Void

    /// Creates the media viewer view.
    init(
        model: NCMediaViewerModel,
        contextMenuController: NCMainTabBarController? = nil,
        navigationBar: UINavigationBar? = nil,
        onVisibleMetadataChanged: @escaping (_ metadata: tableMetadata?, _ backgroundColor: UIColor) -> Void = { _, _ in },
        onZoomChanged: @escaping (Bool) -> Void = { _ in },
        onClose: @escaping (_ ocId: String?) -> Void = { _ in },
        adaptiveControlsState: NCImageAdaptiveControlsState? = nil,
        makeAdaptiveNavigationBar: (() -> UINavigationBar)? = nil,
        onAdaptiveLayoutChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        _model = StateObject(wrappedValue: model)
        self.contextMenuController = contextMenuController
        self.navigationBar = navigationBar
        self.onVisibleMetadataChanged = onVisibleMetadataChanged
        self.onZoomChanged = onZoomChanged
        self.onClose = onClose
        self.adaptiveControlsState = adaptiveControlsState
        self.makeAdaptiveNavigationBar = makeAdaptiveNavigationBar
        self.onAdaptiveLayoutChanged = onAdaptiveLayoutChanged
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let adaptiveControlsState, let makeAdaptiveNavigationBar {
                NCImageAdaptiveLayoutHost(
                    mediaView: pagingView,
                    model: model,
                    state: adaptiveControlsState,
                    makeNavigationBar: makeAdaptiveNavigationBar,
                    isImage: model.selectedMetadata?.classFile == NKTypeClassFile.image.rawValue,
                    onLayoutModeChanged: onAdaptiveLayoutChanged
                )
                .ignoresSafeArea()
            } else {
                pagingView
                    .ignoresSafeArea()

                NCImageControlsView(model: model)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .task {
            await model.loadSelectedPageIfNeeded()
        }
    }

    private var pagingView: NCMediaViewerPagingView {
        NCMediaViewerPagingView(
            model: model,
            contextMenuController: contextMenuController,
            navigationBar: navigationBar,
            onVisibleMetadataChanged: onVisibleMetadataChanged,
            onZoomChanged: onZoomChanged,
            onClose: onClose
        )
    }
}

// MARK: - Media Viewer Preview

#if DEBUG
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
            loader: NCMediaViewerLoader()
        )

        return NCMediaViewerView(model: model)
    }
}
#endif
