// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import AVKit
import UIKit
import SwiftUI
import NextcloudKit

// MARK: - AVPlayer Layer View

/// UIView backed directly by an AVPlayerLayer.
///
/// This is the AVPlayer equivalent of VLC's drawable view:
/// the fullscreen controller owns one stable video surface and attaches the player to it.
final class NCVideoAVPlayerLayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        guard let playerLayer = layer as? AVPlayerLayer else {
            fatalError("NCVideoAVPlayerLayerView must be backed by AVPlayerLayer")
        }

        return playerLayer
    }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }
}

// MARK: - AVPlayer View Controller

/// UIKit-only AVPlayer video controller.
///
/// This controller is intentionally outside the SwiftUI paging hierarchy.
/// It owns one stable AVPlayerLayer-backed view, one AVPlayer, one optional PiP controller,
/// and one shared controls view.
final class NCVideoAVPlayerViewController: UIViewController {

    // MARK: - Input

    private var metadata: tableMetadata
    private var url: URL
    private var previewURL: URL?
    private var userAgent: String?
    private weak var contextMenuController: NCMainTabBarController?

    // MARK: - Paging Callbacks

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onClose: ((_ ocId: String?) -> Void)?
    var canGoPrevious = false
    var canGoNext = false

    // MARK: - Views

    internal let playerContainerView = NCVideoAVPlayerLayerView()
    private let previewImageView = UIImageView()
    internal let controlsView = NCVideoControlsView()

    private let floatingTitleView = NCViewerFloatingTitleView()

    private lazy var floatingTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - AVPlayer

    internal let player = AVPlayer()

    internal var controlsHideTimer: Timer?
    internal var controlsVisible = false
    internal var isScrubbing = false

    private var pictureInPictureController: AVPictureInPictureController?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var preparedURL: URL?

    var isPictureInPictureActive: Bool {
        pictureInPictureController?.isPictureInPictureActive == true
    }

    internal var shouldKeepControlsVisible: Bool {
        player.timeControlStatus != .playing
    }

    internal func setNavigationBarVisible(
        _ isVisible: Bool,
        animated: Bool
    ) {
        navigationController?.setNavigationBarHidden(
            !isVisible,
            animated: animated
        )
    }

    // MARK: - Navigation Items

    private lazy var moreNavigationItem = UIBarButtonItem(
        image: NCImageCache.shared.getImageButtonMore(),
        primaryAction: nil,
        menu: makeMoreMenu()
    )

    private lazy var mediaDetailNavigationItem = UIBarButtonItem(
        image: NCUtility().loadImage(
            named: "info.circle",
            colors: [NCBrandColor.shared.iconImageColor]
        ),
        style: .plain,
        target: self,
        action: #selector(mediaDetailButtonTapped)
    )

    // MARK: - Init

    init(
        metadata: tableMetadata,
        url: URL,
        previewURL: URL?,
        userAgent: String?,
        contextMenuController: NCMainTabBarController?
    ) {
        self.metadata = metadata
        self.url = url
        self.previewURL = previewURL
        self.userAgent = userAgent
        self.contextMenuController = contextMenuController

        super.init(
            nibName: nil,
            bundle: nil
        )

        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        stopControlsHideTimer()
        stop()
        pictureInPictureController?.delegate = nil
        pictureInPictureController = nil
    }

    // MARK: - Lifecycle

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .black
        rootView.isOpaque = true
        rootView.clipsToBounds = true

        playerContainerView.backgroundColor = .black
        playerContainerView.isOpaque = true
        playerContainerView.clipsToBounds = true
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.playerLayer.videoGravity = .resizeAspect

        previewImageView.backgroundColor = .black
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        updatePreviewImage()

        controlsView.delegate = self
        controlsView.alpha = 0
        controlsView.isHidden = true
        controlsView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(playerContainerView)
        rootView.addSubview(previewImageView)
        rootView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            playerContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            previewImageView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: rootView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            controlsView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            controlsView.topAnchor.constraint(equalTo: rootView.topAnchor),
            controlsView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        updateControlsNavigationBar()
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        configureNavigationItem()
        updateTitleLabel(metadata: metadata)
        configureAudioSession()
        configurePlayerLayer()
        configureSwipeGestures()
        configureTapGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        start()
        showControls(animated: false)
        stopControlsHideTimer()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updatePictureInPictureLayout()
        updateControlsNavigationBar()
        configureFloatingTitleViewIfNeeded()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(
            to: size,
            with: coordinator
        )

        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.updatePictureInPictureLayout()
            self?.updateControlsNavigationBar()
            self?.configureFloatingTitleViewIfNeeded()
        })
    }

    // MARK: - Public API

    /// Updates the current AVPlayer input.
    ///
    /// If the URL changes, the current item is stopped and the new item is prepared.
    /// The context menu is refreshed for the new metadata.
    ///
    /// - Parameters:
    ///   - metadata: Updated video metadata.
    ///   - url: Updated playable URL.
    ///   - userAgent: Optional HTTP User-Agent.
    ///   - contextMenuController: Updated context menu controller.
    func update(
        metadata: tableMetadata,
        url: URL,
        previewURL: URL?,
        userAgent: String?,
        contextMenuController: NCMainTabBarController?
    ) {
        let urlChanged = self.url != url

        if urlChanged {
            stop()
        }

        self.metadata = metadata
        self.url = url
        self.previewURL = previewURL
        self.userAgent = userAgent
        self.contextMenuController = contextMenuController
        updatePreviewImage()
        updateTitleLabel(metadata: metadata)

        refreshMoreMenu()

        if urlChanged {
            start()
        }

        updatePlayPauseButton()
        updateProgressControls()
    }

    // MARK: - Navigation

    /// Configures the navigation bar items.
    private func configureNavigationItem() {
        title = nil
        navigationItem.title = nil
        navigationItem.titleView = nil

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )

        navigationItem.rightBarButtonItems = [
            moreNavigationItem,
            mediaDetailNavigationItem
        ]
    }

    /// Configures the floating title view inside the navigation bar chrome.
    private func configureFloatingTitleViewIfNeeded() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        floatingTitleView.attach(to: navigationBar)
    }

    /// Updates the floating title view using the provided video metadata.
    ///
    /// - Parameter metadata: Video metadata used to build the visible title content.
    private func updateTitleLabel(metadata: tableMetadata) {
        let primaryTitle = metadata.fileNameView.isEmpty
            ? metadata.fileName
            : metadata.fileNameView

        floatingTitleView.update(
            primaryText: primaryTitle,
            secondaryText: floatingTitleSecondaryText(for: metadata),
            textColor: .white
        )
    }

    /// Builds the secondary floating title text for the provided metadata.
    ///
    /// - Parameter metadata: Video metadata used to derive the secondary title line.
    /// - Returns: Secondary title text shown below the main title.
    private func floatingTitleSecondaryText(for metadata: tableMetadata) -> String? {
        floatingTitleDateFormatter.string(from: metadata.date as Date)
    }

    /// Rebuilds the More menu using the current metadata.
    private func refreshMoreMenu() {
        moreNavigationItem.menu = makeMoreMenu()
    }

    /// Builds the AVPlayer-specific More menu.
    ///
    /// The menu uses `sender: self`, so menu actions present from the visible
    /// AVPlayer controller instead of the SwiftUI viewer underneath.
    private func makeMoreMenu() -> UIMenu {
        UIMenu(title: "", children: [
            UIDeferredMenuElement.uncached { [weak self] completion in
                guard let self else {
                    completion([])
                    return
                }

                if let menu = NCContextMenuViewer(
                    metadata: self.metadata,
                    controller: self.contextMenuController,
                    viewController: self,
                    webView: false,
                    sender: self
                ).viewMenu() {
                    completion(menu.children)
                } else {
                    completion([])
                }
            }
        ])
    }

    @objc
    private func closeTapped() {
        close()
    }

    @objc
    private func mediaDetailButtonTapped() {
        presentDetailView(animated: true)
    }

    /// Presents the media metadata detail panel for the current video.
    ///
    /// Video metadata usually has no EXIF payload, so the detail view receives an empty EXIF model.
    ///
    /// - Parameter animated: Whether presentation should be animated.
    private func presentDetailView(animated: Bool) {
        let detailView = NCMediaViewerDetailView(
            metadata: metadata,
            exif: ExifData()
        )

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheetPresentationController = hostingController.sheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
            sheetPresentationController.prefersGrabberVisible = true
            sheetPresentationController.preferredCornerRadius = 24
            sheetPresentationController.prefersEdgeAttachedInCompactHeight = true
            sheetPresentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = false
        }

        present(
            hostingController,
            animated: animated
        )
    }

    func close() {
        stopControlsHideTimer()
        stop()

        NCVideoAVPlayerPresenter.clearCurrent(self)

        dismiss(animated: false) { [onClose, metadata] in
            DispatchQueue.main.async {
                onClose?(metadata.ocId)
            }
        }
    }

    func closeImmediately() {
        stopControlsHideTimer()
        stop()

        NCVideoAVPlayerPresenter.clearCurrent(self)

        dismiss(animated: false) { [onClose] in
            onClose?(nil)
        }
    }

    // MARK: - Swipe Navigation

    /// Configures swipe gestures for page navigation and close behavior.
    private func configureSwipeGestures() {
        let previousGesture = UISwipeGestureRecognizer(
            target: self,
            action: #selector(handleSwipe(_:))
        )
        previousGesture.direction = .right
        previousGesture.delegate = self
        view.addGestureRecognizer(previousGesture)

        let nextGesture = UISwipeGestureRecognizer(
            target: self,
            action: #selector(handleSwipe(_:))
        )
        nextGesture.direction = .left
        nextGesture.delegate = self
        view.addGestureRecognizer(nextGesture)

        let closePanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleClosePan(_:))
        )
        closePanGesture.delegate = self
        view.addGestureRecognizer(closePanGesture)
    }

    /// Handles page navigation and close swipe gestures.
    ///
    /// - Parameter gesture: Source swipe gesture recognizer.
    @objc
    private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }

        guard !isPictureInPictureActive else {
            return
        }

        guard !isScrubbing else {
            return
        }

        switch gesture.direction {
        case .left:
            guard canGoNext else {
                return
            }
            onNext?()

        case .right:
            guard canGoPrevious else {
                return
            }
            onPrevious?()

        default:
            break
        }
    }

    /// Handles downward pan gestures by closing the AVPlayer viewer.
    ///
    /// This mirrors the common media viewer drag-to-close behavior: a short downward
    /// drag or a quick downward flick is enough, while horizontal paging still wins
    /// when the gesture is mostly horizontal.
    ///
    /// - Parameter gesture: Source pan gesture recognizer.
    @objc
    private func handleClosePan(_ gesture: UIPanGestureRecognizer) {
        guard !isPictureInPictureActive else {
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        guard translation.y > 0 else {
            return
        }

        switch gesture.state {
        case .ended,
             .cancelled:
            let verticalDistance = translation.y
            let horizontalDistance = abs(translation.x)
            let downwardVelocity = velocity.y
            let isMostlyVertical = verticalDistance > horizontalDistance * 1.10
            let shouldClose = verticalDistance > 70 || downwardVelocity > 550

            guard isMostlyVertical,
                  shouldClose else {
                return
            }

            close()

        default:
            break
        }
    }

    // MARK: - Gesture Handling

    /// Configures a single tap gesture to toggle AVPlayer playback controls.
    private func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleSingleTap(_:))
        )
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
    }

    /// Handles single taps by toggling AVPlayer playback controls.
    ///
    /// Taps are ignored while playback is not running because controls and the
    /// navigation bar must remain visible in prepared, paused, and stopped states.
    ///
    /// - Parameter gesture: Source tap gesture recognizer.
    @objc
    private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        guard !isPictureInPictureActive else {
            return
        }

        guard !shouldKeepControlsVisible else {
            showControls(animated: false)
            stopControlsHideTimer()
            return
        }

        let location = gesture.location(in: view)

        if controlsVisible {
            guard !controlsHitFramesContain(location) else {
                return
            }

            hideControls(animated: true)
        } else {
            showControls(animated: true)
            scheduleControlsHide()
        }
    }

    // MARK: - Playback

    /// Prepares AVPlayer playback without starting it automatically.
    private func start() {
        guard preparedURL != url else {
            updatePlayPauseButton()
            updateProgressControls()
            updateSeekingState()
            return
        }

        preparedURL = url

        let item = AVPlayerItem(asset: makeAsset())

        player.replaceCurrentItem(with: item)
        playerContainerView.player = player
        showPreviewImage()

        configureObservers()
        configurePictureInPicture()
        updatePlayPauseButton()
        updateProgressControls()
        updateSeekingState()

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO AVPlayer UIKit prepared without autoplay ocId \(metadata.ocId), url \(url.absoluteString)",
            consoleOnly: true
        )
    }

    /// Stops AVPlayer playback and releases resources.
    private func stop() {
        preparedURL = nil
        player.pause()
        cleanupObservers()
        player.replaceCurrentItem(with: nil)
        playerContainerView.player = nil
        showPreviewImage()
        pictureInPictureController?.delegate = nil
        pictureInPictureController = nil
        updatePlayPauseButton()
        updateProgressControls()
    }

    /// Creates the AVFoundation asset for the current URL.
    private func makeAsset() -> AVURLAsset {
        guard let userAgent,
              !userAgent.isEmpty,
              !url.isFileURL else {
            return AVURLAsset(url: url)
        }

        return AVURLAsset(
            url: url,
            options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "User-Agent": userAgent
                ]
            ]
        )
    }

    /// Configures the visible AVPlayerLayer used by fullscreen playback.
    private func configurePlayerLayer() {
        playerContainerView.playerLayer.videoGravity = .resizeAspect
        playerContainerView.player = player
    }

    /// Configures Picture in Picture from the visible AVPlayerLayer.
    private func configurePictureInPicture() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else {
            controlsView.setTopActionsMode(.none)
            return
        }

        playerContainerView.player = player
        playerContainerView.playerLayer.videoGravity = .resizeAspect
        playerContainerView.playerLayer.frame = playerContainerView.bounds

        if pictureInPictureController == nil {
            pictureInPictureController = AVPictureInPictureController(
                playerLayer: playerContainerView.playerLayer
            )
            pictureInPictureController?.delegate = self
        }

        controlsView.setTopActionsMode(.pictureInPicture)
    }

    /// Updates Picture in Picture layout without changing playback state.
    private func updatePictureInPictureLayout() {
        playerContainerView.playerLayer.frame = playerContainerView.bounds
    }

    /// Toggles Picture in Picture if available.
    func togglePictureInPicture() {
        guard let pictureInPictureController else {
            return
        }

        if pictureInPictureController.isPictureInPictureActive {
            pictureInPictureController.stopPictureInPicture()
        } else {
            pictureInPictureController.startPictureInPicture()
        }
    }

    /// Configures AVPlayer observers.
    private func configureObservers() {
        cleanupObservers()

        itemStatusObservation = player.currentItem?.observe(
            \.status,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleCurrentItemStatusChange()
            }
        }

        timeControlStatusObservation = player.observe(
            \.timeControlStatus,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            Task { @MainActor in
                self?.handleTimeControlStatusChange()
            }
        }

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC)),
            queue: .main
        ) { [weak self] _ in
            guard let self,
                  !self.isScrubbing else {
                return
            }

            self.updateProgressControls()
        }

        if let currentItem = player.currentItem {
            playbackEndObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: currentItem,
                queue: .main
            ) { [weak self] _ in
                self?.handlePlaybackEnded()
            }
        }
    }

    /// Releases AVPlayer observers owned by this controller.
    private func cleanupObservers() {
        itemStatusObservation?.invalidate()
        timeControlStatusObservation?.invalidate()

        itemStatusObservation = nil
        timeControlStatusObservation = nil

        if let timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }

        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
            self.playbackEndObserver = nil
        }
    }

    /// Handles AVPlayer item status changes.
    private func handleCurrentItemStatusChange() {
        updateProgressControls()
        updatePlayPauseButton()
        updateSeekingState()

        guard player.currentItem?.status == .readyToPlay else {
            return
        }

        if !controlsVisible,
           !isPictureInPictureActive {
            showControls(animated: false)
            scheduleControlsHide()
        }
    }

    /// Handles AVPlayer playback state changes.
    private func handleTimeControlStatusChange() {
        updatePlayPauseButton()

        guard player.timeControlStatus == .playing else {
            showControls(animated: false)
            stopControlsHideTimer()
            return
        }

        hidePreviewImage()

        if controlsVisible {
            scheduleControlsHide()
        }
    }

    /// Updates the fullscreen preview image shown before the first video frame is ready.
    private func updatePreviewImage() {
        guard let previewURL,
              previewURL.isFileURL else {
            previewImageView.image = nil
            previewImageView.isHidden = true
            return
        }

        previewImageView.image = UIImage(contentsOfFile: previewURL.path)
        previewImageView.isHidden = previewImageView.image == nil
        previewImageView.alpha = 1
    }

    /// Shows the preview image while the AVPlayer item is preparing.
    private func showPreviewImage() {
        guard previewImageView.image != nil else {
            previewImageView.isHidden = true
            return
        }

        previewImageView.layer.removeAllAnimations()
        previewImageView.alpha = 1
        previewImageView.isHidden = false
    }

    /// Hides the preview image after AVPlayer actually starts playback.
    private func hidePreviewImage() {
        guard !previewImageView.isHidden else {
            return
        }

        previewImageView.layer.removeAllAnimations()
        previewImageView.alpha = 0
        previewImageView.isHidden = true
    }

    /// Handles playback reaching the end.
    private func handlePlaybackEnded() {
        updatePlayPauseButton()
        updateProgressControls()
        showControls(animated: true)
    }

    /// Updates the shared controls top actions reference using the real navigation bar.
    private func updateControlsNavigationBar() {
        controlsView.setTopActionsNavigationBar(navigationController?.navigationBar)
    }

    /// Returns whether a point is inside one of the visible controls areas.
    ///
    /// - Parameter location: Point in this controller's root view coordinate space.
    /// - Returns: True when the point is inside center or bottom controls.
    internal func controlsHitFramesContain(_ location: CGPoint) -> Bool {
        let topActionsFrame = controlsView.topActionsView.convert(
            controlsView.topActionsView.bounds,
            to: view
        )
        let centerControlsFrame = controlsView.centerControlsView.convert(
            controlsView.centerControlsView.bounds,
            to: view
        )
        let bottomControlsFrame = controlsView.bottomControlsView.convert(
            controlsView.bottomControlsView.bounds,
            to: view
        )

        return topActionsFrame.contains(location)
            || centerControlsFrame.contains(location)
            || bottomControlsFrame.contains(location)
    }

    /// Configures the audio session for movie playback.
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .moviePlayback,
                options: []
            )

            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO AVPlayer audio session error: \(error.localizedDescription)",
                consoleOnly: true
            )
        }
    }

    /// Updates the shared controls play/pause state.
    internal func updatePlayPauseButton() {
        controlsView.updatePlayPauseButton(
            isPlaying: player.timeControlStatus == .playing
        )
    }

    /// Updates the shared controls progress state.
    internal func updateProgressControls() {
        let currentTime = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? 0

        guard currentTime.isFinite,
              duration.isFinite,
              duration > 0 else {
            controlsView.updateProgress(
                progress: 0,
                elapsedText: "0:00",
                remainingText: "−0:00"
            )
            return
        }

        let progress = Float(max(0, min(1, currentTime / duration)))
        let remainingTime = max(0, duration - currentTime)

        controlsView.updateProgress(
            progress: progress,
            elapsedText: Self.formatTime(currentTime),
            remainingText: "−\(Self.formatTime(remainingTime))"
        )
    }

    /// Updates whether seek controls are enabled.
    internal func updateSeekingState() {
        controlsView.setSeekingEnabled(
            player.currentItem?.duration.seconds.isFinite == true
        )
    }

    internal static func formatTime(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Picture in Picture Delegate

extension NCVideoAVPlayerViewController: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO AVPlayer PiP will start",
            consoleOnly: true
        )

        stopControlsHideTimer()
        hideControls(animated: false)
        hidePreviewImage()
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO AVPlayer PiP did start",
            consoleOnly: true
        )

        stopControlsHideTimer()
        hideControls(animated: false)
        hidePreviewImage()
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO AVPlayer PiP will stop",
            consoleOnly: true
        )
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO AVPlayer PiP did stop",
            consoleOnly: true
        )

        updatePlayPauseButton()
        updateProgressControls()
        updateSeekingState()
        showControls(animated: false)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .error,
            message: "VIDEO AVPlayer PiP failed to start: \(error.localizedDescription)",
            consoleOnly: true
        )

        updatePlayPauseButton()
        updateProgressControls()
        updateSeekingState()
        showControls(animated: true)
    }
}

// MARK: - Gesture Delegate

extension NCVideoAVPlayerViewController: UIGestureRecognizerDelegate {

    /// Allows tap gestures to coexist with AVPlayer's view and UIKit controls.
    ///
    /// - Parameters:
    ///   - gestureRecognizer: Gesture recognizer asking for simultaneous recognition.
    ///   - otherGestureRecognizer: Other gesture recognizer involved in the decision.
    /// - Returns: True to avoid AVPlayer/touch handling from suppressing viewer gestures.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    /// Prevents the background tap recognizer from stealing touches that begin on controls.
    ///
    /// - Parameters:
    ///   - gestureRecognizer: Gesture recognizer asking whether it should receive the touch.
    ///   - touch: Source touch.
    /// - Returns: False for visible playback controls, true otherwise.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        guard !isPictureInPictureActive else {
            return false
        }

        guard controlsVisible else {
            return true
        }

        let location = touch.location(in: view)

        if controlsHitFramesContain(location) {
            return false
        }

        return true
    }

    /// Allows the close pan to start only when the gesture is mainly downward.
    ///
    /// - Parameter gestureRecognizer: Gesture recognizer asking whether it should begin.
    /// - Returns: True for non-pan gestures or downward-dominant pan gestures.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else {
            return true
        }

        guard !isPictureInPictureActive else {
            return false
        }

        guard !isScrubbing else {
            return false
        }

        let velocity = (gestureRecognizer as? UIPanGestureRecognizer)?.velocity(in: view) ?? .zero

        guard velocity.y > 0 else {
            return false
        }

        return abs(velocity.y) > abs(velocity.x) * 1.10
    }
}
