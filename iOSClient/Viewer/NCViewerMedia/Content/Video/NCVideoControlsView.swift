// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVKit
import SwiftUI
import UIKit

// MARK: - Video Controls View Delegate

protocol NCVideoControlsViewDelegate: AnyObject {
    func videoControlsDidTapSeekBackward(_ controlsView: NCVideoControlsView)
    func videoControlsDidTapPlayPause(_ controlsView: NCVideoControlsView)
    func videoControlsDidTapSeekForward(_ controlsView: NCVideoControlsView)
    func videoControlsDidTapPictureInPicture(_ controlsView: NCVideoControlsView)
    func videoControlsDidTapAddExternalSubtitle(_ controlsView: NCVideoControlsView)
    func videoControls(_ controlsView: NCVideoControlsView, didSelectSubtitleTrackIndex index: Int32)
    func videoControls(_ controlsView: NCVideoControlsView, didSelectAudioTrackIndex index: Int32)
    func videoControlsDidBeginScrubbing(_ controlsView: NCVideoControlsView)
    func videoControls(_ controlsView: NCVideoControlsView, didScrubTo progress: Float)
    func videoControlsDidEndScrubbing(_ controlsView: NCVideoControlsView, progress: Float)
}

extension NCVideoControlsViewDelegate {
    func videoControlsDidTapPictureInPicture(_ controlsView: NCVideoControlsView) { }

    func videoControlsDidTapAddExternalSubtitle(_ controlsView: NCVideoControlsView) { }

    func videoControls(_ controlsView: NCVideoControlsView, didSelectSubtitleTrackIndex index: Int32) { }

    func videoControls(_ controlsView: NCVideoControlsView, didSelectAudioTrackIndex index: Int32) { }
}

// MARK: - Video Controls Top Actions Mode

enum NCVideoControlsTopActionsMode: Equatable {
    case none
    case pictureInPicture
    case vlcTracks
}

// MARK: - Video Track Menu Item

struct NCVideoTrackMenuItem: Identifiable, Equatable {
    let index: Int32
    let title: String
    let isSelected: Bool

    var id: Int32 {
        index
    }
}

// MARK: - Video Controls View

final class NCVideoControlsView: UIView {

    // MARK: - Public

    weak var delegate: NCVideoControlsViewDelegate?

    // MARK: - Hit Test Proxies

    let centerControlsView = UIView()
    let bottomControlsView = UIView()
    let topActionsView = UIView()

    // MARK: - Layout Constants

    fileprivate static let centerControlsWidth: CGFloat = 220
    fileprivate static let centerControlsHeight: CGFloat = 76
    fileprivate static let bottomControlsHeight: CGFloat = 45
    fileprivate static let bottomControlsHorizontalInset: CGFloat = 28
    fileprivate static let bottomControlsBottomInset: CGFloat = 30
    fileprivate static let topActionsHeight: CGFloat = 46
    fileprivate static let topActionsHorizontalInset: CGFloat = 28
    fileprivate static let topActionsButtonSize: CGFloat = 38
    fileprivate static let topActionsSpacing: CGFloat = 8

    // MARK: - State

    private var state = NCVideoControlsState()
    private var topActionsTopConstraint: NSLayoutConstraint?
    private weak var navigationBar: UINavigationBar?

    private lazy var hostingController = UIHostingController(
        rootView: makeRootView()
    )

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureLayout()
        updateHostedView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureLayout()
        updateHostedView()
    }

    // MARK: - Public Updates

    func updatePlayPauseButton(isPlaying: Bool) {
        state.isPlaying = isPlaying
        updateHostedView()
    }

    func updateProgress(
        progress: Float,
        elapsedText: String,
        remainingText: String
    ) {
        state.progress = max(0, min(1, progress))
        state.elapsedText = elapsedText
        state.remainingText = remainingText
        updateHostedView()
    }

    func setSeekingEnabled(_ isEnabled: Bool) {
        state.isSeekingEnabled = isEnabled
        updateHostedView()
    }

    func setPictureInPictureVisible(_ isVisible: Bool) {
        setTopActionsMode(isVisible ? .pictureInPicture : .none)
    }

    func setVLCTrackControlsVisible(_ isVisible: Bool) {
        setTopActionsMode(isVisible ? .vlcTracks : .none)
    }

    func setTopActionsMode(_ mode: NCVideoControlsTopActionsMode) {
        let didChangeMode = state.topActionsMode != mode
        var didResetTrackItems = false
        let hasTrackItems = !state.subtitleTrackItems.isEmpty || !state.audioTrackItems.isEmpty

        state.topActionsMode = mode

        if mode != .vlcTracks, hasTrackItems {
            state.subtitleTrackItems = []
            state.audioTrackItems = []
            didResetTrackItems = true
        }

        guard didChangeMode || didResetTrackItems else {
            return
        }

        updateHostedView()
    }

    func setSubtitleTrackMenuItems(_ items: [NCVideoTrackMenuItem]) {
        guard state.subtitleTrackItems != items else {
            return
        }

        state.subtitleTrackItems = items
        updateHostedView()
    }

    func setAudioTrackMenuItems(_ items: [NCVideoTrackMenuItem]) {
        guard state.audioTrackItems != items else {
            return
        }

        state.audioTrackItems = items
        updateHostedView()
    }

    // Keeps top actions aligned below the real navigation bar.
    func setTopActionsNavigationBar(_ navigationBar: UINavigationBar?) {
        self.navigationBar = navigationBar
        updateTopActionsPosition()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTopActionsPosition()
    }

    // MARK: - Configuration

    private func configureLayout() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        configureHostingView()
        configureHitTestProxyViews()
    }

    private func configureHostingView() {
        let hostingView = hostingController.view!
        hostingView.backgroundColor = .clear
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(hostingView)

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureHitTestProxyViews() {
        [centerControlsView, bottomControlsView, topActionsView].forEach { proxyView in
            proxyView.backgroundColor = .clear
            proxyView.isUserInteractionEnabled = false
            proxyView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(proxyView)
        }

        let topActionsTopConstraint = topActionsView.topAnchor.constraint(equalTo: topAnchor)
        self.topActionsTopConstraint = topActionsTopConstraint

        NSLayoutConstraint.activate([
            centerControlsView.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerControlsView.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerControlsView.widthAnchor.constraint(equalToConstant: Self.centerControlsWidth),
            centerControlsView.heightAnchor.constraint(equalToConstant: Self.centerControlsHeight),

            bottomControlsView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.bottomControlsHorizontalInset),
            bottomControlsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.bottomControlsHorizontalInset),
            bottomControlsView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Self.bottomControlsBottomInset),
            bottomControlsView.heightAnchor.constraint(equalToConstant: Self.bottomControlsHeight),

            topActionsView.leadingAnchor.constraint(equalTo: leadingAnchor),
            topActionsView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topActionsTopConstraint,
            topActionsView.heightAnchor.constraint(equalToConstant: Self.topActionsHeight)
        ])
    }

    private func updateTopActionsPosition() {
        guard let topActionsTopConstraint else {
            return
        }

        let topOffset: CGFloat

        if let navigationBar {
            let navigationFrame = navigationBar.convert(
                navigationBar.bounds,
                to: self
            )
            topOffset = navigationFrame.maxY
        } else {
            topOffset = safeAreaInsets.top
        }

        guard state.topActionsTopOffset != topOffset else {
            return
        }

        state.topActionsTopOffset = topOffset
        topActionsTopConstraint.constant = topOffset
        updateHostedView()
    }

    private func updateHostedView() {
        hostingController.rootView = makeRootView()
    }

    private func makeRootView() -> NCVideoControlsSwiftUIView {
        NCVideoControlsSwiftUIView(
            state: state,
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
                updateHostedView()
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

// MARK: - SwiftUI State

private struct NCVideoControlsState: Equatable {
    var isPlaying = false
    var progress: Float = 0
    var elapsedText = "0:00"
    var remainingText = "−0:00"
    var isSeekingEnabled = true
    var topActionsMode: NCVideoControlsTopActionsMode = .none
    var subtitleTrackItems: [NCVideoTrackMenuItem] = []
    var audioTrackItems: [NCVideoTrackMenuItem] = []
    var topActionsTopOffset: CGFloat = 0
}

// MARK: - SwiftUI Controls

private struct NCVideoControlsSwiftUIView: View {
    let state: NCVideoControlsState
    let onSeekBackward: () -> Void
    let onPlayPause: () -> Void
    let onSeekForward: () -> Void
    let onScrubBegan: () -> Void
    let onScrubChanged: (Float) -> Void
    let onScrubEnded: (Float) -> Void
    let onPictureInPicture: () -> Void
    let onSubtitleTrackSelected: (_ index: Int32) -> Void
    let onAddExternalSubtitle: () -> Void
    let onAudioTrackSelected: (_ index: Int32) -> Void

    @State private var currentScrubProgress: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                centerControls
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height / 2
                    )

                bottomControls
                    .frame(height: NCVideoControlsView.bottomControlsHeight)
                    .padding(.horizontal, NCVideoControlsView.bottomControlsHorizontalInset)
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height - proxy.safeAreaInsets.bottom - NCVideoControlsView.bottomControlsBottomInset - (NCVideoControlsView.bottomControlsHeight / 2)
                    )

                if state.topActionsMode != .none {
                    topActions
                        .frame(height: NCVideoControlsView.topActionsHeight)
                        .position(
                            x: topActionsCenterX,
                            y: state.topActionsTopOffset + (NCVideoControlsView.topActionsHeight / 2)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.clear)
    }

    private var topActionsCenterX: CGFloat {
        let visibleButtonsCount: CGFloat

        switch state.topActionsMode {
        case .none:
            visibleButtonsCount = 0
        case .pictureInPicture:
            visibleButtonsCount = 2
        case .vlcTracks:
            visibleButtonsCount = 2
        }

        let totalWidth = (visibleButtonsCount * NCVideoControlsView.topActionsButtonSize) + (max(0, visibleButtonsCount - 1) * NCVideoControlsView.topActionsSpacing)
        return NCVideoControlsView.topActionsHorizontalInset + (totalWidth / 2)
    }

    private var centerControls: some View {
        HStack(spacing: 28) {
            circleButton(
                systemName: "gobackward.10",
                size: 44,
                pointSize: 22,
                isEnabled: state.isSeekingEnabled,
                action: onSeekBackward
            )

            circleButton(
                systemName: state.isPlaying ? "pause.fill" : "play.fill",
                size: 62,
                pointSize: 36,
                isEnabled: true,
                action: onPlayPause
            )

            circleButton(
                systemName: "goforward.10",
                size: 44,
                pointSize: 22,
                isEnabled: state.isSeekingEnabled,
                action: onSeekForward
            )
        }
        .frame(
            width: NCVideoControlsView.centerControlsWidth,
            height: NCVideoControlsView.centerControlsHeight
        )
    }

    private var bottomControls: some View {
        HStack(spacing: NCVideoControlsView.topActionsSpacing) {
            timeLabel(state.elapsedText)
                .frame(width: 54)

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
            .tint(.black.opacity(0.38))
            .opacity(state.isSeekingEnabled ? 1 : 0.45)

            timeLabel(state.remainingText)
                .frame(width: 58)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .controlGlassBackground(shape: Capsule())
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 5)
        .contentShape(Capsule())
    }

    private var topActions: some View {
        HStack(spacing: NCVideoControlsView.topActionsSpacing) {
            switch state.topActionsMode {
            case .none:
                EmptyView()

            case .pictureInPicture:
                Button(action: onPictureInPicture) {
                    topActionIcon(
                        systemName: "pip.enter",
                        pointSize: 18
                    )
                }
                .buttonStyle(.plain)

                NCVideoAirPlayRoutePickerView()
                    .frame(
                        width: NCVideoControlsView.topActionsButtonSize,
                        height: NCVideoControlsView.topActionsButtonSize
                    )
                    .controlGlassBackground(shape: Circle())
                    .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 4)

            case .vlcTracks:
                subtitleActionMenu(
                    systemName: "captions.bubble",
                    pointSize: 17,
                    items: state.subtitleTrackItems,
                    emptyTitle: "_no_subtitles_available_",
                    onSelect: onSubtitleTrackSelected,
                    onAddExternalSubtitle: onAddExternalSubtitle
                )

                topActionMenu(
                    systemName: "speaker.wave.2",
                    pointSize: 17,
                    items: state.audioTrackItems,
                    emptyTitle: "_no_audio_tracks_available_",
                    onSelect: onAudioTrackSelected
                )
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
                Label(
                    NSLocalizedString("_add_external_subtitle_", comment: ""),
                    systemImage: "plus"
                )
            }
        } label: {
            topActionIcon(
                systemName: systemName,
                pointSize: pointSize
            )
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
            topActionIcon(
                systemName: systemName,
                pointSize: pointSize
            )
        }
        .buttonStyle(.plain)
    }

    private func topActionIcon(
        systemName: String,
        pointSize: CGFloat
    ) -> some View {
        Image(systemName: systemName)
            .font(.system(size: pointSize, weight: .regular))
            .foregroundStyle(.black.opacity(0.82))
            .frame(
                width: NCVideoControlsView.topActionsButtonSize,
                height: NCVideoControlsView.topActionsButtonSize
            )
            .controlGlassBackground(shape: Circle())
            .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 4)
    }

    private func circleButton(
        systemName: String,
        size: CGFloat,
        pointSize: CGFloat,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else {
                return
            }

            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: pointSize, weight: .regular))
                .foregroundStyle(.black.opacity(0.82))
                .frame(width: size, height: size)
                .controlGlassBackground(shape: Circle())
                .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.black.opacity(0.82))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

// MARK: - AirPlay Route Picker

private struct NCVideoAirPlayRoutePickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.tintColor = .black
        routePickerView.activeTintColor = .black
        routePickerView.prioritizesVideoDevices = true
        return routePickerView
    }

    func updateUIView(
        _ uiView: AVRoutePickerView,
        context: Context
    ) { }
}

private extension View {
    @ViewBuilder
    func controlGlassBackground<BackgroundShape: Shape>(
        shape: BackgroundShape
    ) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular, in: shape)
        } else {
            self
                .background(.white.opacity(0.92))
                .clipShape(shape)
        }
    }
}

// MARK: - Preview

#Preview("Video Controls") {
    NCVideoControlsPreviewView()
        .frame(width: 393, height: 852)
        .background(Color.black)
        .ignoresSafeArea()
}

private struct NCVideoControlsPreviewView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .black
        containerView.clipsToBounds = true

        let imageView = UIImageView(image: UIImage(named: "testimage"))
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let controlsView = NCVideoControlsView()
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.setTopActionsMode(.pictureInPicture)
        controlsView.updatePlayPauseButton(isPlaying: true)
        controlsView.updateProgress(
            progress: 0.42,
            elapsedText: "1:24",
            remainingText: "−2:31"
        )
        controlsView.setSubtitleTrackMenuItems([
            NCVideoTrackMenuItem(index: -1, title: NSLocalizedString("_disable_", comment: ""), isSelected: true),
            NCVideoTrackMenuItem(index: 0, title: "English", isSelected: false)
        ])
        controlsView.setAudioTrackMenuItems([
            NCVideoTrackMenuItem(index: 1, title: "Italian", isSelected: true),
            NCVideoTrackMenuItem(index: 2, title: "English", isSelected: false)
        ])

        containerView.addSubview(imageView)
        containerView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            controlsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            controlsView.topAnchor.constraint(equalTo: containerView.topAnchor),
            controlsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(
        _ uiView: UIView,
        context: Context
    ) { }
}
