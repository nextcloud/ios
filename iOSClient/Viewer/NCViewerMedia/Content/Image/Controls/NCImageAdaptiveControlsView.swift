// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

/// Independent lower layout for image navigation, inline information and thumbnails.
struct NCImageAdaptiveControlsView: View {
    @ObservedObject var model: NCMediaViewerModel
    @ObservedObject var state: NCImageAdaptiveControlsState
    let makeNavigationBar: () -> UINavigationBar

    var body: some View {
        VStack(spacing: 0) {
            NCImageAdaptiveNavigationBar(makeNavigationBar: makeNavigationBar)
                .frame(height: 44)

            if let detailView = state.detailView {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }

            if model.numberOfPages > 1 {
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
                .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .ncViewerBackground(.system)))
    }
}

/// Presentation state shared with the outer controller; image loading and zoom stay in the pager.
@MainActor
final class NCImageAdaptiveControlsState: ObservableObject {
    @Published var detailView: NCMediaViewerDetailView?
}

private struct NCImageAdaptiveNavigationBar: UIViewRepresentable {
    let makeNavigationBar: () -> UINavigationBar

    func makeUIView(context: Context) -> UINavigationBar {
        makeNavigationBar()
    }

    func updateUIView(_ uiView: UINavigationBar, context: Context) { }
}

/// Bridges SwiftUI controls into the shared container without replacing the paging host on folding.
struct NCImageAdaptiveLayoutHost: UIViewControllerRepresentable {
    let mediaView: NCMediaViewerPagingView
    let model: NCMediaViewerModel
    let state: NCImageAdaptiveControlsState
    let makeNavigationBar: () -> UINavigationBar
    let isImage: Bool
    let onLayoutModeChanged: (Bool) -> Void

    func makeUIViewController(context: Context) -> NCImageAdaptiveLayoutController {
        NCImageAdaptiveLayoutController(
            mediaView: mediaView,
            normalControlsView: NCImageControlsView(model: model),
            adaptiveControlsView: NCImageAdaptiveControlsView(
                model: model,
                state: state,
                makeNavigationBar: makeNavigationBar
            ),
            onLayoutModeChanged: onLayoutModeChanged
        )
    }

    func updateUIViewController(_ controller: NCImageAdaptiveLayoutController, context: Context) {
        controller.mediaController.rootView = mediaView
        controller.normalControlsController.rootView = NCImageControlsView(model: model)
        controller.adaptiveControlsView = NCImageAdaptiveControlsView(
            model: model,
            state: state,
            makeNavigationBar: makeNavigationBar
        )
        controller.adaptiveControlsController?.rootView = controller.adaptiveControlsView
        controller.onLayoutModeChanged = onLayoutModeChanged
        controller.loadViewIfNeeded()
        controller.layoutView.isLayoutEnabled = NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled && isImage
    }
}

@MainActor
final class NCImageAdaptiveLayoutController: UIViewController {
    let mediaController: UIHostingController<NCMediaViewerPagingView>
    let normalControlsController: UIHostingController<NCImageControlsView>
    private(set) var adaptiveControlsController: UIHostingController<NCImageAdaptiveControlsView>?
    var adaptiveControlsView: NCImageAdaptiveControlsView
    var onLayoutModeChanged: (Bool) -> Void

    private var hasAttachedAdaptiveControls = false
    private lazy var normalControlsContainer = NCImageControlsContainerView(
        contentView: normalControlsController.view,
        model: normalControlsController.rootView.model
    )

    private(set) lazy var layoutView = NCMediaAdaptiveLayoutView(
        mediaView: mediaController.view,
        normalControlsView: normalControlsContainer,
        adaptiveControlsView: { [weak self] in
            guard let self else {
                return nil
            }
            let controller = UIHostingController(rootView: self.adaptiveControlsView)
            self.addChild(controller)
            self.adaptiveControlsController = controller
            return controller.view
        }
    )

    init(
        mediaView: NCMediaViewerPagingView,
        normalControlsView: NCImageControlsView,
        adaptiveControlsView: NCImageAdaptiveControlsView,
        onLayoutModeChanged: @escaping (Bool) -> Void
    ) {
        mediaController = UIHostingController(rootView: mediaView)
        normalControlsController = UIHostingController(rootView: normalControlsView)
        self.adaptiveControlsView = adaptiveControlsView
        self.onLayoutModeChanged = onLayoutModeChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        // Match the normal pager's ignoresSafeArea: cover the area behind the transparent navbar.
        mediaController.safeAreaRegions = []
        addChild(mediaController)
        addChild(normalControlsController)
        mediaController.view.backgroundColor = .clear
        mediaController.view.clipsToBounds = true
        normalControlsController.view.backgroundColor = .clear
        view = layoutView
        mediaController.didMove(toParent: self)
        normalControlsController.didMove(toParent: self)
        layoutView.onLayoutModeChanged = { [weak self] isFolded in
            // Notify the outer SwiftUI host after UIKit has completed its layout pass.
            Task { @MainActor [weak self] in
                guard let self, self.layoutView.isFoldedLayout == isFolded else {
                    return
                }
                self.onLayoutModeChanged(isFolded)
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let controller = adaptiveControlsController, controller.view.superview != nil,
           !hasAttachedAdaptiveControls {
            controller.didMove(toParent: self)
            hasAttachedAdaptiveControls = true
        }
    }
}

// Let gestures reach the image outside the thumbnail strip of the separate host.
private final class NCImageControlsContainerView: UIView {
    private let model: NCMediaViewerModel

    init(contentView: UIView, model: NCMediaViewerModel) {
        self.model = model
        super.init(frame: .zero)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !model.isChromeHidden, model.numberOfPages > 1,
              point.y >= bounds.height - NCMediaViewerThumbnail.preferredHeight - 40,
              point.y <= bounds.height - 40 else {
            return nil
        }
        return super.hitTest(point, with: event)
    }
}
