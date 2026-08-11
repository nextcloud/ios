// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import AVKit
import UIKit
import NextcloudKit

// MARK: - AVPlayer Layer View

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

final class NCVideoAVPlayerViewController: UIViewController {

    // MARK: - Input

    private var metadata: tableMetadata
    private var preparedPlayback: NCVideoAVPreparedPlayback
    private var url: URL
    private var userAgent: String?
    private var shouldAutoPlayOnStart: Bool
    private var isChromeHidden: Bool
    private weak var contextMenuController: NCMainTabBarController?
    internal var playbackOptions: NCMediaPlaybackOptions

    // MARK: - Paging Callbacks

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onPlaybackEnded: NCMediaPlaybackAdvanceRequest?
    var onClose: ((_ ocId: String?) -> Void)?
    var onPlaybackError: (() -> Void)?
    var canGoPrevious = false
    var canGoNext = false

    // MARK: - Views

    internal let playerContainerView = NCVideoAVPlayerLayerView()
    internal let controlsView = NCVideoControlsView()

    private let floatingTitleView = NCMediaViewerFloatingTitleView()

    private lazy var floatingTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - AVPlayer

    internal var player: AVPlayer

    internal var controlsHideTimer: Timer?
    internal var controlsVisible = false
    private weak var closePanGesture: UIPanGestureRecognizer?

    private var pictureInPictureController: AVPictureInPictureController?
    private var itemStatusObservation: NSKeyValueObservation?
    private var timeControlStatusObservation: NSKeyValueObservation?
    private var playbackEndObserver: NSObjectProtocol?
    private var playbackFailureObserver: NSObjectProtocol?
    private var playbackStartupTimeoutTask: Task<Void, Never>?
    private var timeObserverToken: Any?
    private var preparedURL: URL?
    private var hasReportedPlaybackError = false
    internal var isPlaybackRequested = false
    internal var playbackPresentationContext: NCVideoPlaybackPresentationContext

    var isPictureInPictureActive: Bool {
        pictureInPictureController?.isPictureInPictureActive == true
    }

    internal var shouldKeepControlsVisible: Bool {
        player.timeControlStatus != .playing && !isPlaybackRequested
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

    // MARK: - Init

    init(
        metadata: tableMetadata,
        preparedPlayback: NCVideoAVPreparedPlayback,
        userAgent: String?,
        shouldAutoPlayOnStart: Bool = true,
        playbackStartReason: NCVideoPlaybackPresentationContext.StartReason = .userInitiated,
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?,
        playbackOptions: NCMediaPlaybackOptions
    ) {
        self.metadata = metadata
        self.preparedPlayback = preparedPlayback
        self.url = preparedPlayback.url
        self.player = preparedPlayback.player
        self.userAgent = userAgent
        self.shouldAutoPlayOnStart = shouldAutoPlayOnStart
        self.isChromeHidden = isChromeHidden
        self.contextMenuController = contextMenuController
        self.playbackOptions = playbackOptions
        self.playbackPresentationContext = NCVideoPlaybackPresentationContext(
            startReason: playbackStartReason
        )

        super.init(
            nibName: nil,
            bundle: nil
        )

        modalPresentationStyle = .fullScreen
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
        let initialBackgroundColor = viewerBackgroundColor

        let rootView = UIView()
        rootView.backgroundColor = initialBackgroundColor
        rootView.isOpaque = true
        rootView.clipsToBounds = true

        playerContainerView.backgroundColor = initialBackgroundColor
        playerContainerView.isOpaque = true
        playerContainerView.clipsToBounds = true
        playerContainerView.translatesAutoresizingMaskIntoConstraints = false
        playerContainerView.playerLayer.videoGravity = .resizeAspect

        controlsView.delegate = self
        updatePlaybackOptionsControls()
        controlsView.alpha = 0
        controlsView.isHidden = true
        controlsView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(playerContainerView)
        rootView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            playerContainerView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            playerContainerView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            playerContainerView.topAnchor.constraint(equalTo: rootView.topAnchor),
            playerContainerView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            controlsView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            controlsView.topAnchor.constraint(equalTo: rootView.topAnchor),
            controlsView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        updateControlsNavigationBar()

        if !playbackPresentationContext.shouldShowControlsOnStart {
            controlsView.alpha = 0
            controlsView.isHidden = true
        }

        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = viewerBackgroundColor

        configureNavigationItem()
        updateTitleLabel(metadata: metadata)
        configureAudioSession()
        configurePlayerLayer()
        configureSwipeGestures()
        configureTapGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let shouldPreserveHiddenChromeBackground = isChromeHidden

        start()

        if shouldPreserveHiddenChromeBackground {
            updateViewerBackground(isChromeHidden: true)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updatePictureInPictureLayout()
        updateControlsNavigationBar()
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
        })
    }

    // MARK: - Public API

    func update(
        metadata: tableMetadata,
        preparedPlayback: NCVideoAVPreparedPlayback,
        userAgent: String?,
        shouldAutoPlayOnStart: Bool = true,
        playbackStartReason: NCVideoPlaybackPresentationContext.StartReason = .userInitiated,
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?,
        playbackOptions: NCMediaPlaybackOptions
    ) {
        let urlChanged = self.url != preparedPlayback.url

        if urlChanged {
            stop()
            self.preparedPlayback = preparedPlayback
            self.url = preparedPlayback.url
            self.player = preparedPlayback.player
        }

        self.metadata = metadata
        self.userAgent = userAgent
        self.shouldAutoPlayOnStart = shouldAutoPlayOnStart
        self.playbackPresentationContext.updateStartReason(playbackStartReason)
        self.contextMenuController = contextMenuController
        self.playbackOptions = playbackOptions
        updateViewerBackground(isChromeHidden: isChromeHidden)
        updateTitleLabel(metadata: metadata)

        if urlChanged {
            start()
        }

        updatePlayPauseButton()
        updateProgressControls()
        updatePlaybackOptionsControls()
    }

    private var viewerBackgroundColor: UIColor {
        UIColor.ncViewerBackground(
            ncViewerBackgroundStyle(
                for: metadata,
                isChromeHidden: isChromeHidden
            )
        )
    }

    @MainActor
    internal func updateViewerBackground(isChromeHidden: Bool) {
        self.isChromeHidden = isChromeHidden

        let backgroundColor = viewerBackgroundColor
        view.backgroundColor = backgroundColor
        playerContainerView.backgroundColor = backgroundColor
    }

    // MARK: - Navigation

    private func configureNavigationItem() {
        title = nil
        navigationItem.title = nil
        navigationItem.titleView = floatingTitleView

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func updateTitleLabel(metadata: tableMetadata) {
        let primaryTitle = metadata.fileNameView.isEmpty
            ? metadata.fileName
            : metadata.fileNameView

        floatingTitleView.update(
            primaryText: primaryTitle,
            secondaryText: floatingTitleDateFormatter.string(from: metadata.date as Date)
        )
    }

    @objc
    private func closeTapped() {
        close()
    }

    func close() {
        let closeCallback = onClose
        let closingOcId = metadata.ocId

        NCVideoAVPlayerPresenter.dismiss {
            closeCallback?(closingOcId)
        }
    }

    func closeImmediately() {
        let closeCallback = onClose

        NCVideoAVPlayerPresenter.dismiss {
            closeCallback?(nil)
        }
    }

    // MARK: - Swipe Navigation

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
        self.closePanGesture = closePanGesture
        view.addGestureRecognizer(closePanGesture)
    }

    @objc
    private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended else {
            return
        }

        guard !isPictureInPictureActive else {
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

    // Close only when downward movement wins over horizontal paging.
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

    // Keep controls visible when playback is not running.
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

    private func start() {
        hasReportedPlaybackError = false
        isPlaybackRequested = shouldAutoPlayOnStart
        playbackPresentationContext.prepareForPlaybackStart()
        applyControlsVisibilityOnStart()

        if player.timeControlStatus == .playing {
            playbackPresentationContext.finishPlaybackTransition()
        }

        cancelPlaybackStartupTimeout()

        guard preparedURL != url else {
            startPlaybackStartupTimeout()
            updatePlayPauseButton()
            updateProgressControls()
            updateSeekingState()
            return
        }

        preparedURL = url
        playerContainerView.player = player
        updatePlayPauseButton()

        configureExternalPlayback()
        configureObservers()
        configurePictureInPicture()

        if shouldAutoPlayOnStart,
           player.timeControlStatus != .playing {
            player.play()
            startPlaybackStartupTimeout()
        }

        updatePlayPauseButton()
        updateProgressControls()
        updateSeekingState()
    }

    private func stop() {
        preparedURL = nil
        isPlaybackRequested = false
        playbackPresentationContext.reset()
        cancelPlaybackStartupTimeout()

        player.pause()
        cleanupObservers()

        playerContainerView.player = nil

        pictureInPictureController?.delegate = nil
        pictureInPictureController = nil

        updatePlayPauseButton()
        updateProgressControls()
    }

    func stopForDismissal() {
        stopControlsHideTimer()
        stop()
    }

    private func applyControlsVisibilityOnStart() {
        if playbackPresentationContext.shouldShowControlsOnStart {
            showControls(animated: false)
            stopControlsHideTimer()
        } else {
            hideControls(animated: false)
        }
    }

    private func configurePlayerLayer() {
        playerContainerView.playerLayer.videoGravity = .resizeAspect
        playerContainerView.player = player
    }

    private func configureExternalPlayback() {
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
    }

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

    private func updatePictureInPictureLayout() {
        playerContainerView.playerLayer.frame = playerContainerView.bounds
    }

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
                  !self.playbackPresentationContext.isSeeking else {
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

            playbackFailureObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: currentItem,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.reportPlaybackErrorIfNeeded()
                }
            }
        }
    }

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

        if let playbackFailureObserver {
            NotificationCenter.default.removeObserver(playbackFailureObserver)
            self.playbackFailureObserver = nil
        }
    }

    private func handleCurrentItemStatusChange() {
        updateProgressControls()
        updateSeekingState()

        if player.currentItem?.status == .failed {
            reportPlaybackErrorIfNeeded()
            return
        }

        guard player.currentItem?.status == .readyToPlay else {
            updatePlayPauseButton()
            return
        }

        if shouldAutoPlayOnStart,
           player.timeControlStatus != .playing {
            isPlaybackRequested = true
            updatePlayPauseButton()
            player.play()
        } else {
            updatePlayPauseButton()
        }

        if playbackPresentationContext.shouldShowControlsOnStart,
           !controlsVisible,
           !isPictureInPictureActive {
            showControls(animated: false)
            scheduleControlsHide()
        }
    }

    private func startPlaybackStartupTimeout() {
        cancelPlaybackStartupTimeout()

        guard shouldAutoPlayOnStart,
              player.timeControlStatus != .playing else {
            return
        }

        playbackStartupTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }

            guard let self,
                  self.isPlaybackRequested,
                  self.player.timeControlStatus != .playing else {
                return
            }

            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO AVPlayer playback startup timed out",
                consoleOnly: false
            )

            self.reportPlaybackErrorIfNeeded()
        }
    }

    private func cancelPlaybackStartupTimeout() {
        playbackStartupTimeoutTask?.cancel()
        playbackStartupTimeoutTask = nil
    }

    private func reportPlaybackErrorIfNeeded() {
        guard !hasReportedPlaybackError else {
            return
        }

        hasReportedPlaybackError = true
        playbackPresentationContext.reset()
        isPlaybackRequested = false
        cancelPlaybackStartupTimeout()

        let playerError = player.currentItem?.error as NSError?
        let errorDomain = playerError?.domain ?? "unknown"
        let errorCode = playerError?.code ?? 0

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .error,
            message: "VIDEO AVPlayer playback failed domain: \(errorDomain), code: \(errorCode)",
            consoleOnly: false
        )

        onPlaybackError?()
    }

    private func handleTimeControlStatusChange() {
        switch player.timeControlStatus {
        case .playing:
            isPlaybackRequested = true
            playbackPresentationContext.finishPlaybackTransition()
            cancelPlaybackStartupTimeout()

        case .waitingToPlayAtSpecifiedRate:
            isPlaybackRequested = true

        case .paused:
            if !playbackPresentationContext.shouldSuppressAutomaticControlsPresentation,
               player.currentItem?.status == .readyToPlay ||
                player.currentItem?.status == .failed ||
                player.currentItem == nil {
                isPlaybackRequested = false
            }

        @unknown default:
            break
        }

        updatePlayPauseButton()

        guard player.timeControlStatus == .playing else {
            guard !playbackPresentationContext.shouldSuppressAutomaticControlsPresentation else {
                return
            }

            if !isPlaybackRequested {
                showControls(animated: false)
                stopControlsHideTimer()
            }
            return
        }

        if controlsVisible {
            scheduleControlsHide()
        }
    }

    private func handlePlaybackEnded() {
        isPlaybackRequested = false
        cancelPlaybackStartupTimeout()

        switch playbackOptions.completionAction {
        case .repeatCurrentItem:
            repeatCurrentItem()
            return

        case .playNextItem:
            updatePlayPauseButton()
            updateProgressControls()

            guard let onPlaybackEnded else {
                finishPlaybackWithoutAdvance()
                return
            }

            onPlaybackEnded { [weak self] didAdvance in
                guard !didAdvance else {
                    return
                }

                self?.finishPlaybackWithoutAdvance()
            }
            return

        case .stop:
            break
        }

        finishPlaybackWithoutAdvance()
    }

    private func finishPlaybackWithoutAdvance() {
        updatePlayPauseButton()
        updateProgressControls()
        showControls(animated: true)
        stopControlsHideTimer()
    }

    private func repeatCurrentItem() {
        playbackPresentationContext.beginRepeatRestart()
        isPlaybackRequested = true
        updatePlayPauseButton()

        player.seek(
            to: .zero,
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self, weak player] didFinish in
            guard let self,
                  let player else {
                return
            }

            Task { @MainActor in
                guard self.player === player else {
                    return
                }

                guard didFinish else {
                    self.playbackPresentationContext.finishPlaybackTransition()
                    self.isPlaybackRequested = false
                    self.updatePlayPauseButton()
                    self.showControls(animated: true)
                    return
                }

                player.play()
                self.updateProgressControls()
                self.scheduleControlsHide()
            }
        }
    }

    internal func updatePlaybackOptionsControls() {
        controlsView.updatePlaybackOptions(
            isRepeatEnabled: playbackOptions.isRepeatEnabled,
            isAutoAdvanceEnabled: playbackOptions.isAutoAdvanceEnabled
        )
    }

    private func updateControlsNavigationBar() {
        controlsView.setTopActionsNavigationBar(navigationController?.navigationBar)
    }

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

    internal func updatePlayPauseButton() {
        let isPlaying = player.timeControlStatus == .playing ||
            player.timeControlStatus == .waitingToPlayAtSpecifiedRate ||
            isPlaybackRequested

        controlsView.updatePlayPauseButton(isPlaying: isPlaying)
    }

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

        stopControlsHideTimer()
        hideControls(animated: false)
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {

        stopControlsHideTimer()
        hideControls(animated: false)
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        updatePlayPauseButton()
        updateProgressControls()
        updateSeekingState()
        showControls(animated: false)

        if shouldKeepControlsVisible {
            stopControlsHideTimer()
        } else {
            scheduleControlsHide()
        }
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
    // Keep AVPlayer touches compatible with viewer gestures, but isolate visible controls from global gestures.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard controlsVisible else {
            return true
        }

        let firstGestureIsInsideControls = gestureRecognizer.view?.isDescendant(of: controlsView) == true
        let secondGestureIsInsideControls = otherGestureRecognizer.view?.isDescendant(of: controlsView) == true

        if firstGestureIsInsideControls || secondGestureIsInsideControls {
            return false
        }

        return true
    }

    // Keep global viewer gestures disabled while Picture in Picture is active or when visible controls receive the touch.
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

        return !controlsHitFramesContain(location)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === closePanGesture else {
            return true
        }

        guard !isPictureInPictureActive else {
            return false
        }

        let velocity = closePanGesture?.velocity(in: view) ?? .zero

        guard velocity.y > 0 else {
            return false
        }

        return abs(velocity.y) > abs(velocity.x) * 1.10
    }
}
