// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import UIKit
import MobileVLCKit
import NextcloudKit

// MARK: - VLC View Controller

final class NCVideoVLCViewController: UIViewController {

    // MARK: - Input

    private var metadata: tableMetadata
    private var preparedPlayback: NCVideoVLCPreparedPlayback
    private var url: URL
    private var userAgent: String?
    private var shouldAutoPlayOnStart: Bool
    private var isChromeHidden: Bool
    private weak var contextMenuController: NCMainTabBarController?
    internal var playbackOptions: NCMediaPlaybackOptions
    private var isReplayFromBeginningRequested = false
    internal var playbackPresentationContext: NCVideoPlaybackPresentationContext

    // MARK: - Paging Callbacks

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    var onPlaybackEnded: NCMediaPlaybackAdvanceRequest?
    var onClose: ((_ ocId: String?) -> Void)?
    var onPlaybackError: (() -> Void)?
    var canGoPrevious = false
    var canGoNext = false

    // MARK: - Views

    internal let drawableView = UIView()
    internal let controlsView = NCVideoControlsView()

    private let floatingTitleView = NCMediaViewerFloatingTitleView()

    private lazy var floatingTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    // MARK: - VLC

    internal let mediaPlayer = VLCMediaPlayer()
    private var externalSubtitleURL: URL?
    private var isStopInFlight = false
    private var hasEnteredPlaybackPipeline = false
    private var hasReportedPlaybackError = false
    private var playbackStartupTimeoutTask: Task<Void, Never>?
    private var stopCompletions: [() -> Void] = []

    internal var progressTimer: Timer?
    internal var controlsHideTimer: Timer?
    internal var controlsVisible = false
    internal var isPlaybackRequested = false
    private weak var closePanGesture: UIPanGestureRecognizer?

    internal var shouldKeepControlsVisible: Bool {
        mediaPlayer.state != .playing && !mediaPlayer.isPlaying && !isPlaybackRequested
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
        preparedPlayback: NCVideoVLCPreparedPlayback,
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
        playbackStartupTimeoutTask?.cancel()
        stopControlsHideTimer()
        stopProgressTimer()
        mediaPlayer.delegate = nil
    }

    // MARK: - Lifecycle

    override func loadView() {
        let backgroundColor = viewerBackgroundColor

        let rootView = UIView()
        rootView.backgroundColor = backgroundColor
        rootView.isOpaque = true
        rootView.clipsToBounds = true

        drawableView.backgroundColor = backgroundColor
        drawableView.isOpaque = true
        drawableView.clipsToBounds = true
        drawableView.translatesAutoresizingMaskIntoConstraints = false

        controlsView.delegate = self
        controlsView.setTopActionsMode(.vlcTracks)
        updatePlaybackOptionsControls()
        controlsView.alpha = 0
        controlsView.isHidden = true
        controlsView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(drawableView)
        rootView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            drawableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            drawableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            drawableView.topAnchor.constraint(equalTo: rootView.topAnchor),
            drawableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            controlsView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            controlsView.topAnchor.constraint(equalTo: rootView.topAnchor),
            controlsView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor)
        ])

        controlsView.setTopActionsNavigationBar(navigationController?.navigationBar)

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
        mediaPlayer.delegate = self
        configureSwipeGestures()
        configureTapGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        attachDrawable()
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
            self?.attachDrawable()
            self?.updateControlsNavigationBar()
        })
    }

    // MARK: - Public API

    func update(
        metadata: tableMetadata,
        preparedPlayback: NCVideoVLCPreparedPlayback,
        userAgent: String?,
        shouldAutoPlayOnStart: Bool = true,
        playbackStartReason: NCVideoPlaybackPresentationContext.StartReason = .userInitiated,
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?,
        playbackOptions: NCMediaPlaybackOptions
    ) {
        let urlChanged = self.url != preparedPlayback.url
        let applyConfiguration = { [weak self] in
            guard let self else { return }

            self.metadata = metadata
            self.userAgent = userAgent
            self.shouldAutoPlayOnStart = shouldAutoPlayOnStart
            self.playbackPresentationContext.updateStartReason(playbackStartReason)
            self.isChromeHidden = isChromeHidden
            self.contextMenuController = contextMenuController
            self.playbackOptions = playbackOptions
            self.updateViewerBackgroundIfNeeded()
            self.updateTitleLabel(metadata: metadata)
            self.refreshVLCTrackMenuItemsWhenPlayerIsActive()
            self.updatePlayPauseButton()
            self.updatePlaybackOptionsControls()
        }

        guard urlChanged else {
            applyConfiguration()
            return
        }

        stop { [weak self] in
            guard let self else { return }

            self.preparedPlayback = preparedPlayback
            self.url = preparedPlayback.url
            applyConfiguration()
            self.start()
        }
    }

    private var viewerBackgroundColor: UIColor {
        UIColor.ncViewerBackground(
            ncViewerBackgroundStyle(
                for: metadata,
                isChromeHidden: isChromeHidden
            )
        )
    }

    private func updateViewerBackgroundIfNeeded() {
        guard !controlsVisible else {
            return
        }

        let backgroundColor = viewerBackgroundColor
        view.backgroundColor = backgroundColor
        drawableView.backgroundColor = backgroundColor
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

        NCVideoVLCPresenter.dismiss {
            closeCallback?(closingOcId)
        }
    }

    func closeImmediately() {
        let closeCallback = onClose

        NCVideoVLCPresenter.dismiss {
            closeCallback?(nil)
        }
    }

    // MARK: - Swipe Navigation

    private func configureSwipeGestures() {
        let swipeLeft = UISwipeGestureRecognizer(
            target: self,
            action: #selector(handleSwipe(_:))
        )
        swipeLeft.direction = .left
        swipeLeft.delegate = self

        let swipeRight = UISwipeGestureRecognizer(
            target: self,
            action: #selector(handleSwipe(_:))
        )
        swipeRight.direction = .right
        swipeRight.delegate = self

        let closePanGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handleClosePan(_:))
        )
        closePanGesture.delegate = self
        self.closePanGesture = closePanGesture

        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
        view.addGestureRecognizer(closePanGesture)
    }

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

    @objc
    private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
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

    // MARK: - Playback

    private func start() {
        hasEnteredPlaybackPipeline = false
        hasReportedPlaybackError = false
        isPlaybackRequested = shouldAutoPlayOnStart
        playbackPresentationContext.prepareForPlaybackStart()
        applyControlsVisibilityOnStart()

        if mediaPlayer.state == .playing {
            playbackPresentationContext.finishPlaybackTransition()
        }

        cancelPlaybackStartupTimeout()
        attachDrawable()

        mediaPlayer.media = preparedPlayback.media
        updatePlayPauseButton()

        if shouldAutoPlayOnStart {
            logPlaybackRequest()
            mediaPlayer.play()
            startPlaybackStartupTimeout()
        }

        updatePlayPauseButton()
        updateProgressControls()
        clearVLCTrackMenuItems()
        startProgressTimer()
    }

    private func applyControlsVisibilityOnStart() {
        if playbackPresentationContext.shouldShowControlsOnStart {
            showControls(animated: false)
            stopControlsHideTimer()
        } else {
            hideControls(animated: false)
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        if let completion {
            stopCompletions.append(completion)
        }

        guard !isStopInFlight else { return }

        let hadPendingPlaybackRequest = isPlaybackRequested
        stopControlsHideTimer()
        stopProgressTimer()
        cancelPlaybackStartupTimeout()
        isPlaybackRequested = false
        isReplayFromBeginningRequested = false
        playbackPresentationContext.reset()

        if mediaPlayer.media == nil ||
            (mediaPlayer.state == .stopped && !hadPendingPlaybackRequest) {
            finishStop()
            return
        }

        isStopInFlight = true
        mediaPlayer.stop()
    }

    func stopForDismissal() {
        // A queued URL replacement no longer applies once this controller is
        // leaving the screen and must not restart playback after dismissal.
        stopCompletions.removeAll()
        stop()
    }

    private func finishStop() {
        isStopInFlight = false
        mediaPlayer.media = nil
        mediaPlayer.drawable = nil
        externalSubtitleURL = nil
        updatePlayPauseButton()
        updateProgressControls()
        clearVLCTrackMenuItems()

        let completions = stopCompletions
        stopCompletions.removeAll()
        completions.forEach { $0() }
    }

    func restartPlaybackFromBeginning() {
        isReplayFromBeginningRequested = true
        isPlaybackRequested = true
        updatePlayPauseButton()

        if mediaPlayer.state == .stopped {
            startReplayAfterStop()
        } else {
            mediaPlayer.stop()
        }
    }

    private func startReplayAfterStop() {
        guard isReplayFromBeginningRequested else {
            return
        }

        isReplayFromBeginningRequested = false
        hasEnteredPlaybackPipeline = false

        let media = VLCMedia(url: url)

        if let userAgent,
           !userAgent.isEmpty,
           !url.isFileURL {
            media.addOption(":http-user-agent=\(userAgent)")
        }

        mediaPlayer.media = media
        mediaPlayer.play()
        startPlaybackStartupTimeout()

        startProgressTimer()
        scheduleControlsHide()
    }

    private func attachDrawable() {
        guard drawableView.bounds.width > 0,
              drawableView.bounds.height > 0 else {
            return
        }

        if let currentDrawable = mediaPlayer.drawable as? UIView,
           currentDrawable === drawableView {
            return
        }

        mediaPlayer.drawable = drawableView
    }

    private func logPlaybackRequest() {
        let scheme = url.scheme ?? "unknown"
        let host = url.host ?? (url.isFileURL ? "local" : "unknown")

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .start,
            message: "VIDEO VLC play requested scheme: \(scheme), host: \(host)",
            consoleOnly: false
        )
    }

    private func startPlaybackStartupTimeout() {
        cancelPlaybackStartupTimeout()

        guard isPlaybackRequested,
              !mediaPlayer.isPlaying,
              mediaPlayer.state != .playing else {
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
                  !self.mediaPlayer.isPlaying,
                  self.mediaPlayer.state != .playing else {
                return
            }

            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO VLC playback startup timed out",
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
        onPlaybackError?()
    }

    private func handleMediaPlayerStateChange() {
        let stateDescription: String

        switch mediaPlayer.state {
        case .stopped:
            stateDescription = "stopped"
        case .opening:
            stateDescription = "opening"
        case .buffering:
            stateDescription = "buffering"
        case .ended:
            stateDescription = "ended"
        case .error:
            stateDescription = "error"
        case .playing:
            stateDescription = "playing"
        case .paused:
            stateDescription = "paused"
        default:
            stateDescription = "unknown"
        }

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: mediaPlayer.state == .error ? .error : .debug,
            message: "VIDEO VLC state: \(stateDescription)",
            consoleOnly: false
        )

        if isStopInFlight {
            if mediaPlayer.state == .stopped {
                finishStop()
            }
            return
        }

        if mediaPlayer.state == .error {
            reportPlaybackErrorIfNeeded()
            return
        }

        switch mediaPlayer.state {
        case .opening,
             .buffering,
             .playing:
            hasEnteredPlaybackPipeline = true

        default:
            break
        }

        switch mediaPlayer.state {
        case .playing:
            isPlaybackRequested = true
            playbackPresentationContext.finishPlaybackTransition()
            cancelPlaybackStartupTimeout()

        case .ended:
            isPlaybackRequested = false
            stopProgressTimer()

            switch playbackOptions.completionAction {
            case .repeatCurrentItem:
                playbackPresentationContext.beginRepeatRestart()
                restartPlaybackFromBeginning()
                return

            case .playNextItem:
                updatePlayPauseButton()
                updateProgressLabels(position: 1)

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
            return

        case .stopped:
            if isReplayFromBeginningRequested {
                startReplayAfterStop()
                return
            }

            if isPlaybackRequested,
               hasEnteredPlaybackPipeline {
                nkLog(
                    tag: NCGlobal.shared.logTagViewer,
                    emoji: .error,
                    message: "VIDEO VLC playback stopped before reaching playing",
                    consoleOnly: false
                )
                reportPlaybackErrorIfNeeded()
                return
            }

            isPlaybackRequested = false
            cancelPlaybackStartupTimeout()

        case .paused:
            if !playbackPresentationContext.shouldSuppressAutomaticControlsPresentation {
                isPlaybackRequested = false
            }

        case .error:
            playbackPresentationContext.reset()
            isPlaybackRequested = false

        default:
            break
        }

        updatePlayPauseButton()
        updateProgressControls()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()

        guard mediaPlayer.state == .playing else {
            guard !playbackPresentationContext.shouldSuppressAutomaticControlsPresentation else {
                return
            }

            if !isPlaybackRequested {
                showControls(animated: false)
                stopControlsHideTimer()
            }
            return
        }

        scheduleControlsHideIfNeededAfterPlaybackStart()
    }

    // Safe to call from both state and time callbacks.
    private func scheduleControlsHideIfNeededAfterPlaybackStart() {
        guard !shouldKeepControlsVisible else {
            return
        }

        guard controlsVisible else {
            return
        }

        guard controlsHideTimer == nil else {
            return
        }

        scheduleControlsHide()
    }

    internal func updatePlaybackOptionsControls() {
        controlsView.updatePlaybackOptions(
            isRepeatEnabled: playbackOptions.isRepeatEnabled,
            isAutoAdvanceEnabled: playbackOptions.isAutoAdvanceEnabled
        )
    }

    // MARK: - VLC Track Menus

    func refreshVLCTrackMenuItems() {
        controlsView.setSubtitleTrackMenuItems(makeSubtitleTrackMenuItems())
        controlsView.setAudioTrackMenuItems(makeAudioTrackMenuItems())
    }

    func clearVLCTrackMenuItems() {
        controlsView.setSubtitleTrackMenuItems([])
        controlsView.setAudioTrackMenuItems([])
    }

    func refreshVLCTrackMenuItemsWhenPlayerIsActive() {
        switch mediaPlayer.state {
        case .opening, .buffering, .playing, .paused:
            refreshVLCTrackMenuItems()
        default:
            clearVLCTrackMenuItems()
        }
    }

    private func finishPlaybackWithoutAdvance() {
        updatePlayPauseButton()
        updateProgressLabels(position: 1)
        showControls(animated: true)
        stopControlsHideTimer()
    }

    func selectSubtitleTrack(index: Int32) {
        mediaPlayer.currentVideoSubTitleIndex = index

        NCManageDatabase.shared.addVideo(
            metadata: metadata,
            currentVideoSubTitleIndex: Int(index)
        )

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.refreshVLCTrackMenuItemsWhenPlayerIsActive()
        }
    }

    func selectAudioTrack(index: Int32) {
        mediaPlayer.currentAudioTrackIndex = index

        NCManageDatabase.shared.addVideo(
            metadata: metadata,
            currentAudioTrackIndex: Int(index)
        )

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            self?.refreshVLCTrackMenuItemsWhenPlayerIsActive()
        }
    }

    func presentExternalSubtitlePicker() {
        guard presentedViewController == nil,
              let navigationController = makeExternalSubtitlePicker() else {
            return
        }

        navigationController.modalPresentationStyle = .formSheet
        present(navigationController, animated: true)
    }

    private func makeExternalSubtitlePicker() -> UINavigationController? {
        let session = NCSession.shared.getSession(account: metadata.account)

        guard !session.account.isEmpty,
              let navigationController = UIStoryboard(
                  name: "NCSelect",
                  bundle: nil
              ).instantiateInitialViewController() as? UINavigationController,
              let rootViewController = navigationController.topViewController as? NCSelect else {
            return nil
        }

        let utilityFileSystem = NCUtilityFileSystem()
        let homeServerUrl = utilityFileSystem.getHomeServer(session: session)
        var serverUrl = metadata.serverUrl
        var viewControllers: [NCSelect] = []

        while true {
            let viewController: NCSelect?

            if serverUrl == homeServerUrl {
                viewController = rootViewController
            } else {
                viewController = UIStoryboard(
                    name: "NCSelect",
                    bundle: nil
                ).instantiateViewController(
                    withIdentifier: "NCSelect.storyboard"
                ) as? NCSelect
            }

            guard let viewController else {
                return nil
            }

            configureExternalSubtitlePicker(
                viewController,
                serverUrl: serverUrl,
                homeServerUrl: homeServerUrl,
                session: session
            )
            viewControllers.insert(viewController, at: 0)

            guard serverUrl != homeServerUrl,
                  let parentServerUrl = utilityFileSystem.serverDirectoryUp(
                      serverUrl: serverUrl,
                      home: homeServerUrl
                  ) else {
                break
            }

            serverUrl = parentServerUrl
        }

        navigationController.setViewControllers(viewControllers, animated: false)
        return navigationController
    }

    private func configureExternalSubtitlePicker(
        _ viewController: NCSelect,
        serverUrl: String,
        homeServerUrl: String,
        session: NCSession.Session
    ) {
        let folderName = (serverUrl as NSString).lastPathComponent.removingPercentEncoding

        viewController.delegate = self
        viewController.typeOfCommandView = .nothing
        viewController.enableSelectFile = true
        viewController.allowedFileExtensions = supportedExternalSubtitleExtensions
        viewController.titleCurrentFolder = serverUrl == homeServerUrl
            ? NCBrandOptions.shared.brand
            : folderName ?? (serverUrl as NSString).lastPathComponent
        viewController.serverUrl = serverUrl
        viewController.session = session
        viewController.controller = contextMenuController
        viewController.navigationItem.backButtonTitle = viewController.titleCurrentFolder
    }

    private var supportedExternalSubtitleExtensions: Set<String> {
        ["srt", "vtt", "ass", "ssa", "sub"]
    }

    private func isSupportedExternalSubtitleURL(_ url: URL) -> Bool {
        supportedExternalSubtitleExtensions.contains(url.pathExtension.lowercased())
    }

    private func loadExternalSubtitle(url: URL) {
        guard isSupportedExternalSubtitleURL(url) else {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO VLC unsupported external subtitle extension: \(url.lastPathComponent)",
                consoleOnly: true
            )
            return
        }

        do {
            let localURL = try copyExternalSubtitleToTemporaryDirectory(from: url)

            externalSubtitleURL = localURL

            _ = mediaPlayer.addPlaybackSlave(
                localURL.standardizedFileURL,
                type: .subtitle,
                enforce: true
            )

            refreshExternalSubtitleTracksAfterLoad()
        } catch {
            nkLog(
                tag: NCGlobal.shared.logTagViewer,
                emoji: .error,
                message: "VIDEO VLC external subtitle load error: \(error.localizedDescription)",
                consoleOnly: true
            )
        }
    }

    // Copy to a stable temporary file readable by VLC.
    private func copyExternalSubtitleToTemporaryDirectory(from url: URL) throws -> URL {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileName = url.lastPathComponent.isEmpty
            ? "external-subtitle.\(url.pathExtension.lowercased())"
            : url.lastPathComponent

        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vlc-external-subtitles", isDirectory: true)
            .appendingPathComponent(fileName)

        let destinationDirectory = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        try FileManager.default.copyItem(
            at: url,
            to: destinationURL
        )

        return destinationURL
    }

    private func refreshExternalSubtitleTracksAfterLoad() {
        refreshVLCTrackMenuItems()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.refreshVLCTrackMenuItems()
        }
    }

    private func makeSubtitleTrackMenuItems() -> [NCVideoTrackMenuItem] {
        makeTrackMenuItems(
            titles: mediaPlayer.videoSubTitlesNames,
            indexes: mediaPlayer.videoSubTitlesIndexes,
            currentIndex: currentSubtitleTrackIndex()
        )
    }

    private func makeAudioTrackMenuItems() -> [NCVideoTrackMenuItem] {
        makeTrackMenuItems(
            titles: mediaPlayer.audioTrackNames,
            indexes: mediaPlayer.audioTrackIndexes,
            currentIndex: currentAudioTrackIndex()
        )
    }

    private func currentSubtitleTrackIndex() -> Int? {
        let playerIndex = Int(mediaPlayer.currentVideoSubTitleIndex)

        if playerIndex >= 0 {
            return playerIndex
        }

        return NCManageDatabase.shared.getVideo(metadata: metadata)?.currentVideoSubTitleIndex
    }

    private func currentAudioTrackIndex() -> Int? {
        let playerIndex = Int(mediaPlayer.currentAudioTrackIndex)

        if playerIndex >= 0 {
            return playerIndex
        }

        return NCManageDatabase.shared.getVideo(metadata: metadata)?.currentAudioTrackIndex
    }

    private func makeTrackMenuItems(
        titles: [Any],
        indexes: [Any],
        currentIndex: Int?
    ) -> [NCVideoTrackMenuItem] {
        titles.indices.compactMap { index in
            guard let title = titles[index] as? String,
                  let trackIndex = normalizedTrackIndex(indexes, at: index) else {
                return nil
            }

            return NCVideoTrackMenuItem(
                index: trackIndex,
                title: title,
                isSelected: currentIndex == Int(trackIndex)
            )
        }
    }

    private func normalizedTrackIndex(
        _ indexes: [Any],
        at index: Int
    ) -> Int32? {
        guard indexes.indices.contains(index) else {
            return nil
        }

        switch indexes[index] {
        case let value as Int32:
            return value
        case let value as Int:
            return Int32(value)
        case let value as NSNumber:
            return value.int32Value
        default:
            return nil
        }
    }

    // MARK: - Helpers

    private func updateControlsNavigationBar() {
        controlsView.setTopActionsNavigationBar(navigationController?.navigationBar)
    }

    private func controlsHitFramesContain(_ location: CGPoint) -> Bool {
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
                message: "VIDEO VLC audio session error: \(error.localizedDescription)",
                consoleOnly: true
            )
        }
    }
}

// MARK: - VLC Delegate

extension NCVideoVLCViewController: VLCMediaPlayerDelegate {
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            handleMediaPlayerStateChange()
        }
    }

    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            guard !playbackPresentationContext.isSeeking else {
                return
            }

            updateProgressControls()
            scheduleControlsHideIfNeededAfterPlaybackStart()
        }
    }
}

// MARK: - Gesture Delegate

extension NCVideoVLCViewController: UIGestureRecognizerDelegate {
    // Keep VLC drawable touches compatible with viewer gestures, but isolate visible controls from global gestures.
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

    // Keep global viewer gestures disabled when visible controls receive the touch.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
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

        let velocity = closePanGesture?.velocity(in: view) ?? .zero

        guard velocity.y > 0 else {
            return false
        }

        return abs(velocity.y) > abs(velocity.x) * 1.10
    }
}

// MARK: - Nextcloud Subtitle Picker Delegate

extension NCVideoVLCViewController: NCSelectDelegate {
    func dismissSelect(
        serverUrl: String?,
        metadata: tableMetadata?,
        type: String,
        items: [Any],
        overwrite: Bool,
        copy: Bool,
        move: Bool,
        session: NCSession.Session,
        controller: NCMainTabBarController?
    ) {
        guard let metadata else {
            showControls(animated: true)
            return
        }

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            let utilityFileSystem = NCUtilityFileSystem()

            if !utilityFileSystem.fileProviderStorageExists(metadata) {
                let result = await NCNetworking.shared.downloadFile(metadata: metadata)

                guard result.nkError == .success else {
                    nkLog(
                        tag: NCGlobal.shared.logTagViewer,
                        emoji: .error,
                        message: "VIDEO VLC subtitle download error: \(result.nkError.errorDescription)",
                        consoleOnly: true
                    )
                    showControls(animated: true)
                    return
                }
            }

            let localPath = utilityFileSystem.getDirectoryProviderStorageOcId(
                metadata.ocId,
                fileName: metadata.fileName,
                userId: metadata.userId,
                urlBase: metadata.urlBase
            )

            loadExternalSubtitle(url: URL(fileURLWithPath: localPath))
            showControls(animated: true)
        }
    }
}
