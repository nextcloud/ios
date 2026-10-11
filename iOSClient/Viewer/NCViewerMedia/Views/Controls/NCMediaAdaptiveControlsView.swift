// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

// MARK: - Lower panel composition

/// Common lower panel: buttons, replaceable media controls and a persistent thumbnail strip.
/// Keep thumbnail visibility outside the media-specific content and information panel.
struct NCMediaAdaptiveControlsView: View {
    @ObservedObject var model: NCMediaViewerModel
    @ObservedObject var state: NCMediaAdaptiveControlsState
    let makeActionsView: () -> UIView

    var body: some View {
        VStack(spacing: 0) {
            NCMediaAdaptiveActionsHost(makeActionsView: makeActionsView)
                .frame(height: NCMediaAdaptiveActionsView.preferredHeight)
                .layoutPriority(1)

            mediaControls
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(pageSwipe)

            if model.numberOfPages > 1 {
                NCMediaViewerThumbnailStrip(model: model)
                    .padding(.vertical, 12)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .ncViewerBackground(.system)))
    }

    // Keep page swipes outside the buttons and independently scrolling thumbnail strip.
    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let translation = value.translation
                guard state.isFoldedLayout,
                      abs(translation.width) >= 50,
                      abs(translation.width) > abs(translation.height) else { return }

                let index = model.selectedIndex + (translation.width < 0 ? 1 : -1)
                guard index >= 0, index < model.numberOfPages else { return }

                Task { await model.displayPreviewPage(at: index) }
            }
    }

    // Add media-specific lower controls here; the buttons and thumbnails stay shared.
    @ViewBuilder
    private var mediaControls: some View {
        if let detailView = state.detailView {
            detailView
        } else if let ocId = model.selectedMetadata?.ocId,
                  let controls = state.videoCoverControls(for: ocId) {
            NCVideoPlaybackCoverControlsView(presentation: controls)
        } else {
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Shared presentation state

/// Video cover registrations store media data and actions rather than rendered control views.
/// Ownership prevents neighboring or reused pages from removing the selected cover actions.
@MainActor
final class NCMediaAdaptiveControlsState: ObservableObject {
    @Published var detailView: NCMediaViewerDetailView?
    @Published var isFoldedLayout = false
    private struct VideoCoverRegistration {
        let owner: UUID
        let controls: NCVideoPlaybackCoverPresentation
    }

    @Published private var videoCoverRegistrations: [String: VideoCoverRegistration] = [:]

    func videoCoverControls(for ocId: String) -> NCVideoPlaybackCoverPresentation? {
        videoCoverRegistrations[ocId]?.controls
    }

    func setVideoCoverControls(_ controls: NCVideoPlaybackCoverPresentation, for ocId: String, owner: UUID) {
        videoCoverRegistrations[ocId] = VideoCoverRegistration(owner: owner, controls: controls)
    }

    func removeVideoCoverControls(for ocId: String, owner: UUID) {
        guard videoCoverRegistrations[ocId]?.owner == owner else {
            return
        }
        videoCoverRegistrations.removeValue(forKey: ocId)
    }
}

// Paging cells have separate hosting controllers, so the context is injected into each page.
struct NCMediaAdaptiveCoverContext: Sendable {
    let state: NCMediaAdaptiveControlsState
    let ocId: String
}

private struct NCMediaAdaptiveCoverContextKey: EnvironmentKey {
    static let defaultValue: NCMediaAdaptiveCoverContext? = nil
}

extension EnvironmentValues {
    var mediaAdaptiveCoverContext: NCMediaAdaptiveCoverContext? {
        get { self[NCMediaAdaptiveCoverContextKey.self] }
        set { self[NCMediaAdaptiveCoverContextKey.self] = newValue }
    }
}

/// Standalone actions, without navigation items, title or navigation-bar appearance.
final class NCMediaAdaptiveActionsView: UIStackView {
    static let preferredHeight: CGFloat = 56

    init(closeAction: UIAction, moreButton: UIButton, infoAction: UIAction? = nil) {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center
        spacing = 12
        layoutMargins = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        isLayoutMarginsRelativeArrangement = true

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.accessibilityLabel = NSLocalizedString("_close_", comment: "")
        closeButton.addAction(closeAction, for: .touchUpInside)
        addArrangedSubview(closeButton)
        addArrangedSubview(UIView())

        if let infoAction {
            let infoButton = UIButton(type: .system)
            infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
            infoButton.accessibilityLabel = NSLocalizedString("_info_", comment: "")
            infoButton.addAction(infoAction, for: .touchUpInside)
            addArrangedSubview(infoButton)
            informationButton = infoButton
        }
        addArrangedSubview(moreButton)
        for button in arrangedSubviews.compactMap({ $0 as? UIButton }) {
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 44),
                button.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }

    private(set) var informationButton: UIButton?

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct NCMediaAdaptiveActionsHost: UIViewRepresentable {
    let makeActionsView: () -> UIView

    func makeUIView(context: Context) -> UIView {
        makeActionsView()
    }

    func updateUIView(_ uiView: UIView, context: Context) { }
}

// MARK: - Stable paging bridge

/// Bridges SwiftUI controls into the shared container without replacing the paging host on folding.
/// Layout edits belong in the lower composition above; keep these hosts stable to preserve page state.
struct NCMediaAdaptiveLayoutHost: UIViewControllerRepresentable {
    let mediaView: NCMediaViewerPagingView
    let model: NCMediaViewerModel
    let state: NCMediaAdaptiveControlsState
    let makeActionsView: () -> UIView
    let supportsAdaptiveLayout: Bool
    let onLayoutModeChanged: (Bool) -> Void

    private var adaptiveControlsView: NCMediaAdaptiveControlsView {
        NCMediaAdaptiveControlsView(model: model, state: state, makeActionsView: makeActionsView)
    }

    func makeUIViewController(context: Context) -> NCMediaAdaptiveLayoutController {
        NCMediaAdaptiveLayoutController(
            mediaView: mediaView,
            normalControlsView: NCImageControlsView(model: model),
            adaptiveControlsView: adaptiveControlsView,
            onLayoutModeChanged: onLayoutModeChanged
        )
    }

    func updateUIViewController(_ controller: NCMediaAdaptiveLayoutController, context: Context) {
        controller.mediaController.rootView = mediaView
        controller.normalControlsController.rootView = NCImageControlsView(model: model)
        controller.adaptiveControlsView = adaptiveControlsView
        controller.onLayoutModeChanged = onLayoutModeChanged
        controller.loadViewIfNeeded()
        controller.layoutView.isLayoutEnabled = NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled && supportsAdaptiveLayout
    }
}

@MainActor
final class NCMediaAdaptiveLayoutController: UIViewController {
    let mediaController: UIHostingController<NCMediaViewerPagingView>
    let normalControlsController: UIHostingController<NCImageControlsView>
    private(set) var adaptiveControlsController: UIHostingController<NCMediaAdaptiveControlsView>?
    var adaptiveControlsView: NCMediaAdaptiveControlsView {
        didSet {
            adaptiveControlsController?.rootView = adaptiveControlsView
        }
    }
    var onLayoutModeChanged: (Bool) -> Void

    private var hasAttachedAdaptiveControls = false
    private lazy var normalControlsContainer = NCMediaNormalControlsContainerView(contentView: normalControlsController.view, model: normalControlsController.rootView.model)

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
        adaptiveControlsView: NCMediaAdaptiveControlsView,
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
private final class NCMediaNormalControlsContainerView: UIView {
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
