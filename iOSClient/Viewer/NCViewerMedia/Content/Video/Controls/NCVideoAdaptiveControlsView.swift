// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

final class NCVideoAdaptiveControlsView: UIView, NCVideoPlaybackControls {

    // MARK: - Public

    weak var delegate: NCVideoControlsViewDelegate?
    let actionsContainerView = UIView()
    let pagingFooterView = UIView()
    private var pagingModel: NCMediaViewerModel?
    private var onSelectPage: ((_ index: Int) -> Void)?
    private var pagingFooterController: UIHostingController<NCMediaAdaptivePagingFooterView>?
    private var hostingBottomConstraint: NSLayoutConstraint?

    // MARK: - Hit Test Proxies

    let centerControlsView = UIView()
    let bottomControlsView = UIView()
    let topActionsView = UIView()

    // MARK: - Layout Constants

    fileprivate static let topActionsButtonWidth: CGFloat = 44

    // MARK: - State

    // Keep the hosted hierarchy stable so playback updates do not dismiss an open menu.
    let state: NCVideoControlsState
    private let layoutState = NCVideoControlsLayoutState()
    private var topActionsWidthConstraint: NSLayoutConstraint?

    private lazy var hostingController = UIHostingController(rootView: makeRootView())
    private lazy var topActionsHostingController = UIHostingController(rootView: makeRootView(isTopActionsOnly: true))

    // MARK: - Init

    override init(frame: CGRect) {
        state = NCVideoControlsState()
        super.init(frame: frame)
        configureLayout()
    }

    init(state: NCVideoControlsState) {
        self.state = state
        super.init(frame: .zero)
        configureLayout()
    }

    required init?(coder: NSCoder) {
        state = NCVideoControlsState()
        super.init(coder: coder)
        configureLayout()
    }

    /// Called only for the folded player; normal controls never create this footer.
    func configurePaging(model: NCMediaViewerModel?, onSelectPage: @escaping (_ index: Int) -> Void) {
        pagingModel = model
        self.onSelectPage = onSelectPage
        guard let model else {
            pagingFooterController?.view.removeFromSuperview()
            pagingFooterController = nil
            setNeedsLayout()
            return
        }
        let root = NCMediaAdaptivePagingFooterView(model: model, navigationHeight: NCMediaAdaptiveControlsLayout.actionsHeight, onSelectPage: onSelectPage)
        if let pagingFooterController {
            pagingFooterController.rootView = root
        } else {
            let controller = UIHostingController(rootView: root)
            controller.overrideUserInterfaceStyle = .dark
            controller.safeAreaRegions = []
            controller.view.backgroundColor = .clear
            pagingFooterView.addSubview(controller.view)
            pagingFooterController = controller
        }
        setNeedsLayout()
    }

    // MARK: - Public Updates

    func updatePlayPauseButton(isPlaying: Bool) {
        guard state.isPlaying != isPlaying else {
            return
        }

        state.isPlaying = isPlaying
    }

    func updateProgress(progress: Float, elapsedText: String, remainingText: String) {
        let progress = max(0, min(1, progress))

        guard state.progress != progress ||
                state.elapsedText != elapsedText ||
                state.remainingText != remainingText else {
            return
        }

        state.progress = progress
        state.elapsedText = elapsedText
        state.remainingText = remainingText
    }

    func setSeekingEnabled(_ isEnabled: Bool) {
        guard state.isSeekingEnabled != isEnabled else {
            return
        }

        state.isSeekingEnabled = isEnabled
    }

    func updatePlaybackOptions(isRepeatEnabled: Bool, isAutoAdvanceEnabled: Bool) {
        if state.isRepeatEnabled != isRepeatEnabled {
            state.isRepeatEnabled = isRepeatEnabled
        }

        if state.isAutoAdvanceEnabled != isAutoAdvanceEnabled {
            state.isAutoAdvanceEnabled = isAutoAdvanceEnabled
        }
    }

    func setPictureInPictureVisible(_ isVisible: Bool) {
        setTopActionsMode(isVisible ? .pictureInPicture : .none)
    }

    func setVLCTrackControlsVisible(_ isVisible: Bool) {
        setTopActionsMode(isVisible ? .vlcTracks : .none)
    }

    func setTopActionsMode(_ mode: NCVideoControlsTopActionsMode) {
        let didChangeMode = state.topActionsMode != mode
        let hasTrackItems = !state.subtitleTrackItems.isEmpty || !state.audioTrackItems.isEmpty

        if didChangeMode {
            state.topActionsMode = mode
        }

        updateTopActionsWidth()

        if mode != .vlcTracks, hasTrackItems {
            state.subtitleTrackItems = []
            state.audioTrackItems = []
        }
    }

    func setSubtitleTrackMenuItems(_ items: [NCVideoTrackMenuItem]) {
        guard state.subtitleTrackItems != items else {
            return
        }

        state.subtitleTrackItems = items
    }

    func setAudioTrackMenuItems(_ items: [NCVideoTrackMenuItem]) {
        guard state.audioTrackItems != items else {
            return
        }

        state.audioTrackItems = items
    }

    func configureAdaptiveActions(closeAction: UIAction, moreButton: UIButton) {
        actionsContainerView.subviews.forEach { $0.removeFromSuperview() }
        let actionsView = NCMediaAdaptiveActionsView(closeAction: closeAction, moreButton: moreButton, buttonWidth: Self.topActionsButtonWidth)
        topActionsHostingController.overrideUserInterfaceStyle = .dark
        topActionsHostingController.safeAreaRegions = []
        let playbackActions = topActionsHostingController.view!
        playbackActions.backgroundColor = .clear
        playbackActions.translatesAutoresizingMaskIntoConstraints = false
        actionsView.insertArrangedSubview(playbackActions, at: 1)
        let widthConstraint = playbackActions.widthAnchor.constraint(equalToConstant: 0)
        topActionsWidthConstraint = widthConstraint
        NSLayoutConstraint.activate([
            widthConstraint,
            playbackActions.heightAnchor.constraint(equalToConstant: NCMediaAdaptiveControlsLayout.actionsHeight)
        ])
        updateTopActionsWidth()
        actionsView.overrideUserInterfaceStyle = .dark
        actionsView.translatesAutoresizingMaskIntoConstraints = false
        actionsContainerView.addSubview(actionsView)
        NSLayoutConstraint.activate([
            actionsView.leadingAnchor.constraint(equalTo: actionsContainerView.leadingAnchor),
            actionsView.trailingAnchor.constraint(equalTo: actionsContainerView.trailingAnchor),
            actionsView.topAnchor.constraint(equalTo: actionsContainerView.topAnchor),
            actionsView.bottomAnchor.constraint(equalTo: actionsContainerView.bottomAnchor)
        ])
    }

    func setFileName(_ name: String, account: String = "") {
        (actionsContainerView.subviews.first as? NCMediaAdaptiveActionsView)?.setFileName(name)
        if layoutState.account != account { layoutState.account = account }
    }

    // Adaptive actions are already in the standalone header.
    func setTopActionsNavigationBar(_ navigationBar: UINavigationBar?) {
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let spacing = NCMediaAdaptiveControlsLayout.spacing
        actionsContainerView.frame = CGRect(
            x: spacing, y: safeAreaInsets.top + spacing,
            width: max(0, bounds.width - spacing * 2), height: NCMediaAdaptiveActionsView.preferredHeight
        )
        updatePagingFooterLayout()
        updateTopActionsWidth()
        let contentTop = actionsContainerView.frame.maxY + spacing
        if layoutState.topActionsTopOffset != contentTop { layoutState.topActionsTopOffset = contentTop }
        let contentBottom = max(contentTop, bounds.height - (hostingBottomConstraint.map { -$0.constant } ?? 0))
        let contentHeight = max(0, contentBottom - contentTop)
        let progressHeight = min(NCMediaAdaptiveControlsLayout.actionsHeight, max(0, contentHeight - spacing))
        centerControlsView.frame = CGRect(x: spacing, y: contentTop, width: max(0, bounds.width - spacing * 2), height: max(0, contentHeight - progressHeight - spacing))
        bottomControlsView.frame = CGRect(x: spacing, y: contentBottom - progressHeight, width: max(0, bounds.width - spacing * 2), height: progressHeight)
        topActionsView.frame = actionsContainerView.frame
    }

    private func updatePagingFooterLayout() {
        var footerHeight: CGFloat = 0
        if let model = pagingModel, let onSelectPage, let controller = pagingFooterController {
            // Same middle-area budget and navigation height as paged image/audio controls.
            let middleHeight = NCMediaAdaptiveControlsLayout.middleHeight(panelHeight: bounds.height)
            let navigationHeight = NCMediaAdaptiveControlsLayout.navigationHeight(availableHeight: middleHeight)
            footerHeight = NCMediaAdaptiveControlsLayout.footerHeight(navigationHeight: navigationHeight)
            if controller.rootView.navigationHeight != navigationHeight {
                controller.rootView = NCMediaAdaptivePagingFooterView(model: model, navigationHeight: navigationHeight, onSelectPage: onSelectPage)
            }
            pagingFooterView.frame = CGRect(x: 0, y: max(0, bounds.height - footerHeight), width: bounds.width, height: footerHeight)
            controller.view.frame = pagingFooterView.bounds
        } else {
            pagingFooterView.frame = .zero
        }
        hostingBottomConstraint?.constant = -footerHeight
    }

    // MARK: - Configuration

    private func configureLayout() {
        // Presented adaptive video always uses black, including when controls are visible.
        overrideUserInterfaceStyle = .dark
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        configureHostingView()
        configureHitTestProxyViews()
        actionsContainerView.isHidden = false
        addSubview(actionsContainerView)
        addSubview(pagingFooterView)
    }

    private func configureHostingView() {
        hostingController.overrideUserInterfaceStyle = .dark
        hostingController.safeAreaRegions = []
        let hostingView = hostingController.view!
        hostingView.backgroundColor = .clear
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hostingView)

        let bottomConstraint = hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        hostingBottomConstraint = bottomConstraint
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            bottomConstraint
        ])
    }

    private func configureHitTestProxyViews() {
        [centerControlsView, bottomControlsView, topActionsView].forEach { proxyView in
            proxyView.backgroundColor = .clear
            proxyView.isUserInteractionEnabled = false
            addSubview(proxyView)
        }
    }

    private func updateTopActionsWidth() {
        let count: CGFloat = state.topActionsMode == .none ? 2 : 4
        topActionsWidthConstraint?.constant = count * Self.topActionsButtonWidth + (count - 1) * NCMediaAdaptiveControlsLayout.spacing
    }

    private func makeRootView(isTopActionsOnly: Bool = false) -> NCVideoAdaptiveControlsSwiftUIView {
        NCVideoAdaptiveControlsSwiftUIView(
            state: state,
            layoutState: layoutState,
            isTopActionsOnly: isTopActionsOnly,
            onSeekBackward: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidTapSeekBackward(self)
            },
            onPlayPause: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidTapPlayPause(self)
            },
            onSeekForward: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidTapSeekForward(self)
            },
            onToggleRepeat: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidToggleRepeat(self)
            },
            onToggleAutoAdvance: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidToggleAutoAdvance(self)
            },
            onScrubBegan: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidBeginScrubbing(self)
            },
            onScrubChanged: { [weak self] progress in
                guard let self else {
                    return
                }
                state.progress = progress
                delegate?.videoControls(self, didScrubTo: progress)
            },
            onScrubEnded: { [weak self] progress in
                guard let self else {
                    return
                }
                state.progress = progress
                delegate?.videoControlsDidEndScrubbing(self, progress: progress)
            },
            onPictureInPicture: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidTapPictureInPicture(self)
            },
            onSubtitleTrackSelected: { [weak self] index in
                guard let self else {
                    return
                }
                delegate?.videoControls(self, didSelectSubtitleTrackIndex: index)
            },
            onAddExternalSubtitle: { [weak self] in
                guard let self else {
                    return
                }
                delegate?.videoControlsDidTapAddExternalSubtitle(self)
            },
            onAudioTrackSelected: { [weak self] index in
                guard let self else {
                    return
                }
                delegate?.videoControls(self, didSelectAudioTrackIndex: index)
            }
        )
    }
}

// MARK: - Adaptive SwiftUI Controls

private struct NCVideoAdaptiveControlsSwiftUIView: View {
    @ObservedObject var state: NCVideoControlsState
    @ObservedObject var layoutState: NCVideoControlsLayoutState
    let isTopActionsOnly: Bool
    let onSeekBackward: () -> Void
    let onPlayPause: () -> Void
    let onSeekForward: () -> Void
    let onToggleRepeat: () -> Void
    let onToggleAutoAdvance: () -> Void
    let onScrubBegan: () -> Void
    let onScrubChanged: (Float) -> Void
    let onScrubEnded: (Float) -> Void
    let onPictureInPicture: () -> Void
    let onSubtitleTrackSelected: (_ index: Int32) -> Void
    let onAddExternalSubtitle: () -> Void
    let onAudioTrackSelected: (_ index: Int32) -> Void

    @State private var currentScrubProgress: Double?

    var body: some View {
        if isTopActionsOnly {
            topActions
        } else {
            GeometryReader { proxy in
                let spacing = NCMediaAdaptiveControlsLayout.spacing
                let contentTop = layoutState.topActionsTopOffset
                let contentHeight = max(0, proxy.size.height - contentTop)
                let progressHeight = min(NCMediaAdaptiveControlsLayout.actionsHeight, max(0, contentHeight - spacing))
                VStack(spacing: spacing) {
                    centerControls
                        .frame(maxHeight: .infinity)
                    bottomControls
                        .frame(height: progressHeight)
                        .layoutPriority(1)
                }
                .frame(height: contentHeight)
                .padding(.horizontal, spacing)
                .padding(.top, contentTop)
                .clipped()
            }
        }
    }

    private var centerControls: some View {
        HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            controlButton(systemName: "gobackward.10", title: "_seek_backward_10_", isEnabled: state.isSeekingEnabled, action: onSeekBackward)
            controlButton(systemName: state.isPlaying ? "pause.fill" : "play.fill", title: state.isPlaying ? "_pause_" : "_play_", isEnabled: true, action: onPlayPause)
            controlButton(systemName: "goforward.10", title: "_seek_forward_10_", isEnabled: state.isSeekingEnabled, action: onSeekForward)
        }
    }

    private var bottomControls: some View {
        HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            Slider(
                value: Binding(
                    get: {
                        currentScrubProgress ?? Double(state.progress)
                    },
                    set: { progress in
                        currentScrubProgress = progress
                        onScrubChanged(Float(progress))
                    }
                ),
                in: 0...1,
                onEditingChanged: { isEditing in
                    if isEditing {
                        currentScrubProgress = Double(state.progress)
                        onScrubBegan()
                    } else {
                        let progress = Float(currentScrubProgress ?? Double(state.progress))
                        currentScrubProgress = nil
                        onScrubEnded(progress)
                    }
                }
            )
            .disabled(!state.isSeekingEnabled)
            .tint(Color.ncViewerAdaptiveProgressTint(account: layoutState.account))
            .opacity(state.isSeekingEnabled ? 1 : 0.45)

            timeLabel(state.remainingText.trimmingCharacters(in: CharacterSet(charactersIn: "−-")))
                .fixedSize()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ncAdaptiveControlSurface(shape: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var topActions: some View {
        HStack(spacing: NCMediaAdaptiveControlsLayout.spacing) {
            Button(action: onToggleRepeat) {
                topActionIcon(systemName: state.isRepeatEnabled ? "repeat.1.circle.fill" : "repeat.1", pointSize: 17)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("_repeat_current_media_", comment: ""))

            Button(action: onToggleAutoAdvance) {
                topActionIcon(systemName: state.isAutoAdvanceEnabled ? "forward.end.fill" : "forward.end", pointSize: 17)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(NSLocalizedString("_play_next_media_automatically_", comment: ""))

            switch state.topActionsMode {
            case .none:
                EmptyView()

            case .pictureInPicture:
                Button(action: onPictureInPicture) {
                    topActionIcon(systemName: "pip.enter", pointSize: 18)
                }
                .buttonStyle(.plain)

                NCVideoAirPlayRoutePickerView()
                    .frame(width: NCVideoAdaptiveControlsView.topActionsButtonWidth, height: NCMediaAdaptiveControlsLayout.actionsHeight)
                    .ncAdaptiveControlSurface(shape: RoundedRectangle(cornerRadius: 12))

            case .vlcTracks:
                subtitleActionMenu(
                    systemName: "captions.bubble",
                    pointSize: 17,
                    items: state.subtitleTrackItems,
                    emptyTitle: "_no_subtitles_available_",
                    onSelect: onSubtitleTrackSelected,
                    onAddExternalSubtitle: onAddExternalSubtitle
                )

                topActionMenu(systemName: "speaker.wave.2", pointSize: 17, items: state.audioTrackItems, emptyTitle: "_no_audio_tracks_available_", onSelect: onAudioTrackSelected)
            }
        }
    }

    private func subtitleActionMenu(
        systemName: String,
        pointSize: CGFloat,
        items: [NCVideoTrackMenuItem],
        emptyTitle: String,
        onSelect: @escaping (_ index: Int32) -> Void,
        onAddExternalSubtitle: @escaping () -> Void
    ) -> some View {
        return Menu {
            if items.isEmpty {
                Text(NSLocalizedString(emptyTitle, comment: ""))
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item.index)
                    } label: {
                        HStack {
                            Text(item.title)

                            if item.isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                onAddExternalSubtitle()
            } label: {
                Label(NSLocalizedString("_add_external_subtitle_", comment: ""), systemImage: "plus")
            }
        } label: {
            topActionIcon(systemName: systemName, pointSize: pointSize)
        }
        .buttonStyle(.plain)
    }

    private func topActionMenu(
        systemName: String,
        pointSize: CGFloat,
        items: [NCVideoTrackMenuItem],
        emptyTitle: String,
        onSelect: @escaping (_ index: Int32) -> Void
    ) -> some View {
        return Menu {
            if items.isEmpty {
                Text(NSLocalizedString(emptyTitle, comment: ""))
            } else {
                ForEach(items) { item in
                    Button {
                        onSelect(item.index)
                    } label: {
                        HStack {
                            Text(item.title)

                            if item.isSelected {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            topActionIcon(systemName: systemName, pointSize: pointSize)
        }
        .buttonStyle(.plain)
    }

    private func topActionIcon(systemName: String, pointSize: CGFloat) -> some View {
        Image(systemName: systemName)
            .font(.system(size: pointSize, weight: .bold))
            .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
            .frame(width: NCVideoAdaptiveControlsView.topActionsButtonWidth, height: NCMediaAdaptiveControlsLayout.actionsHeight)
            .ncAdaptiveControlSurface(shape: RoundedRectangle(cornerRadius: 12))
    }

    private func controlButton(systemName: String, title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ncAdaptiveControlSurface(shape: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityLabel(NSLocalizedString(title, comment: ""))
        .transaction { $0.animation = nil }
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.monospacedDigit())
            .fontWeight(.bold)
            .foregroundStyle(Color.ncViewerAdaptiveControlForeground)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}
