// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import NextcloudKit

// MARK: - Lower panel composition

/// Common lower panel: buttons, replaceable media controls and a persistent thumbnail strip.
/// Keep thumbnail visibility outside the media-specific content and information panel.
struct NCMediaAdaptiveControlsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var model: NCMediaViewerModel
    @ObservedObject var state: NCMediaAdaptiveControlsState
    let makeActionsView: () -> UIView

    var body: some View {
        let contentStyle = ncViewerBackgroundStyle(for: model.selectedMetadata, isChromeHidden: model.isChromeHidden)
        let backgroundStyle = ncViewerAdaptivePanelBackgroundStyle(contentStyle: contentStyle)
        VStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            NCMediaAdaptiveActionsHost(makeActionsView: makeActionsView, showsInformation: model.selectedMetadata?.classFile == NKTypeClassFile.image.rawValue)
                .frame(height: NCMediaAdaptiveActionsView.preferredHeight)
                .layoutPriority(1)

            mediaControls
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(pageSwipe, including: isPageSwipeEnabled ? .all : .subviews)

            ZStack {
                if model.numberOfPages > 1 {
                    NCMediaViewerThumbnailStrip(model: model)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: NCMediaViewerThumbnail.preferredHeight)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
        }
        .padding(NCMediaAdaptiveControlsLayout.spacing)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ncViewerBackground(backgroundStyle))
        .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
        .fontWeight(.bold)
        .tint(Color.ncViewerAdaptiveControlForeground)
        .environment(\.colorScheme, ncViewerAdaptiveControlsColorScheme(for: backgroundStyle, inherited: colorScheme))
        // The adaptive footer reaches the lower region's bottom; keep top/side safe areas for actions.
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // Audio handles swipes locally outside its slider; keep this common gesture away from seeking.
    // Other media preserve information scrolling/map gestures and the action/thumbnail rows.
    private var isPageSwipeEnabled: Bool {
        state.isFoldedLayout && state.detailView == nil && model.numberOfPages > 1 && model.selectedMetadata?.classFile != NKTypeClassFile.audio.rawValue
    }

    private var pageSwipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let translation = value.translation
                guard isPageSwipeEnabled,
                      model.pageTransition.isIdle,
                      abs(translation.width) >= 50,
                      abs(translation.width) > abs(translation.height) else { return }

                selectAdjacentPage(offset: translation.width < 0 ? 1 : -1)
            }
    }

    // Add media-specific lower controls here; the buttons and thumbnails stay shared.
    @ViewBuilder
    private var mediaControls: some View {
        if let metadata = model.selectedMetadata, metadata.classFile == NKTypeClassFile.image.rawValue {
            NCImageAdaptiveControlsView(
                metadata: metadata,
                exif: state.imageInformation?.ocId == metadata.ocId ? state.imageInformation?.exif : nil,
                detailView: state.detailView?.metadata.ocId == metadata.ocId ? state.detailView : nil,
                canGoPrevious: model.selectedIndex > 0,
                canGoNext: model.selectedIndex < model.numberOfPages - 1,
                onPrevious: { selectAdjacentPage(offset: -1) },
                onNext: { selectAdjacentPage(offset: 1) }
            )
        } else if let metadata = model.selectedMetadata, metadata.classFile == NKTypeClassFile.audio.rawValue {
            NCAudioAdaptiveControlsView(
                playbackModel: NCAudioViewerPlaybackRegistry.shared.model(for: metadata.ocId),
                playbackOptions: model.playbackOptions,
                isSelected: isSelectedAudioReady,
                canGoPrevious: model.selectedIndex > 0,
                canGoNext: model.selectedIndex < model.numberOfPages - 1,
                onPrevious: { selectAdjacentPage(offset: -1) },
                onNext: { selectAdjacentPage(offset: 1) }
            )
        } else if let metadata = model.selectedMetadata, metadata.classFile == NKTypeClassFile.video.rawValue {
            GeometryReader { geometry in
                let navigationHeight = NCMediaAdaptiveControlsLayout.navigationHeight(availableHeight: geometry.size.height)
                VStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
                    Group {
                        if let controls = state.videoCoverControls(for: metadata.ocId) {
                            NCVideoAdaptivePlaybackCoverControlsView(presentation: controls)
                        } else {
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    NCMediaAdaptivePagingFooterView(model: model, navigationHeight: navigationHeight, onSelectPage: { index in
                        selectAdjacentPage(offset: index - model.selectedIndex)
                    })
                    .pageNavigation
                    .frame(height: navigationHeight)
                }
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    private var isSelectedAudioReady: Bool {
        guard model.activePageIndex == model.selectedIndex,
              let page = model.selectedPageModel(), case .audio = page.state else { return false }
        return true
    }

    private func selectAdjacentPage(offset: Int) {
        guard state.isFoldedLayout, model.numberOfPages > 1, model.pageTransition.isIdle else { return }
        let sourceIndex = model.selectedIndex
        let index = sourceIndex + offset
        guard index >= 0, index < model.numberOfPages else { return }
        Task {
            guard state.isFoldedLayout, model.pageTransition.isIdle, model.selectedIndex == sourceIndex else { return }
            await model.displayPreviewPage(at: index)
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
    /// Retain only the last inspected image's EXIF for its compact summary; no automatic original download.
    @Published var imageInformation: (ocId: String, exif: ExifData)?
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
    static var preferredHeight: CGFloat { NCMediaAdaptiveControlsLayout.actionsHeight }

    init(closeAction: UIAction, moreButton: UIButton, infoAction: UIAction? = nil) {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center
        distribution = .fillEqually
        spacing = NCMediaAdaptiveControlsLayout.spacing
        layoutMargins = .zero
        isLayoutMarginsRelativeArrangement = true

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.accessibilityLabel = NSLocalizedString("_close_", comment: "")
        closeButton.addAction(closeAction, for: .touchUpInside)
        addArrangedSubview(closeButton)

        if let infoAction {
            let infoButton = UIButton(type: .system)
            infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
            infoButton.accessibilityLabel = NSLocalizedString("_info_", comment: "")
            infoButton.addAction(infoAction, for: .touchUpInside)
            addArrangedSubview(infoButton)
            informationButton = infoButton
        }
        moreButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        addArrangedSubview(moreButton)
        for button in arrangedSubviews.compactMap({ $0 as? UIButton }) {
            var configuration = button.configuration ?? .plain()
            configuration.image = button.image(for: .normal)
            configuration.baseForegroundColor = .ncViewerAdaptiveControlForeground
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(weight: .bold)
            configuration.background.backgroundColor = .ncViewerAdaptiveControlBackground
            configuration.background.strokeColor = .ncViewerAdaptiveControlBorder
            configuration.background.strokeWidth = 0.5
            configuration.background.cornerRadius = 12
            button.configuration = configuration
            NSLayoutConstraint.activate([
                button.heightAnchor.constraint(equalToConstant: Self.preferredHeight)
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
    let showsInformation: Bool

    func makeUIView(context: Context) -> UIView {
        makeActionsView()
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Keep UIKit action colors in sync with the lower panel's SwiftUI appearance.
        uiView.overrideUserInterfaceStyle = context.environment.colorScheme == .dark ? .dark : .light
        // UIStackView removes the hidden image-only button from its layout and accessibility.
        (uiView as? NCMediaAdaptiveActionsView)?.informationButton?.isHidden = !showsInformation
    }
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
