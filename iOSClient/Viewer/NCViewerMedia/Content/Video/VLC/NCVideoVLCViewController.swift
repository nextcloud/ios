// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import UIKit
import MobileVLCKit
import NextcloudKit
import UniformTypeIdentifiers

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
    private var isReplayFromBeginningRequested = false

    // MARK: - Paging Callbacks

    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
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
    private var hasReportedPlaybackError = false
    private var stopCompletions: [() -> Void] = []

    internal var progressTimer: Timer?
    internal var controlsHideTimer: Timer?
    internal var controlsVisible = false
    internal var isScrubbing = false
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
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?
    ) {
        self.metadata = metadata
        self.preparedPlayback = preparedPlayback
        self.url = preparedPlayback.url
        self.userAgent = userAgent
        self.shouldAutoPlayOnStart = shouldAutoPlayOnStart
        self.isChromeHidden = isChromeHidden
        self.contextMenuController = contextMenuController

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
        showControls(animated: false)
        stopControlsHideTimer()
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
        isChromeHidden: Bool = false,
        contextMenuController: NCMainTabBarController?
    ) {
        let urlChanged = self.url != preparedPlayback.url
        let applyConfiguration = { [weak self] in
            guard let self else { return }

            self.metadata = metadata
            self.userAgent = userAgent
            self.shouldAutoPlayOnStart = shouldAutoPlayOnStart
            self.isChromeHidden = isChromeHidden
            self.contextMenuController = contextMenuController
            self.updateViewerBackgroundIfNeeded()
            self.updateTitleLabel(metadata: metadata)
            self.refreshVLCTrackMenuItemsWhenPlayerIsActive()
            self.updatePlayPauseButton()
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
        hasReportedPlaybackError = false
        isPlaybackRequested = shouldAutoPlayOnStart
        attachDrawable()

        mediaPlayer.media = preparedPlayback.media
        updatePlayPauseButton()

        if shouldAutoPlayOnStart {
            logPlaybackRequest()
            mediaPlayer.play()
        }

        updatePlayPauseButton()
        updateProgressControls()
        clearVLCTrackMenuItems()
        startProgressTimer()
        showControls(animated: false)
        stopControlsHideTimer()
    }

    func stop(completion: (() -> Void)? = nil) {
        if let completion {
            stopCompletions.append(completion)
        }

        guard !isStopInFlight else { return }

        let hadPendingPlaybackRequest = isPlaybackRequested
        stopControlsHideTimer()
        stopProgressTimer()
        isPlaybackRequested = false
        isReplayFromBeginningRequested = false

        if mediaPlayer.media == nil ||
            (mediaPlayer.state == .stopped && !hadPendingPlaybackRequest) {
            finishStop()
            return
        }

        isStopInFlight = true
        mediaPlayer.stop()
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

        let media = VLCMedia(url: url)

        if let userAgent,
           !userAgent.isEmpty,
           !url.isFileURL {
            media.addOption(":http-user-agent=\(userAgent)")
        }

        mediaPlayer.media = media
        mediaPlayer.play()

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

    private func reportPlaybackErrorIfNeeded() {
        guard !hasReportedPlaybackError else {
            return
        }

        hasReportedPlaybackError = true
        isPlaybackRequested = false
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
        case .playing:
            isPlaybackRequested = true

        case .ended:
            isPlaybackRequested = false
            stopProgressTimer()
            updatePlayPauseButton()
            updateProgressLabels(position: 1)
            showControls(animated: true)
            stopControlsHideTimer()
            return

        case .stopped:
            if isReplayFromBeginningRequested {
                startReplayAfterStop()
                return
            }

            isPlaybackRequested = false

        case .paused,
             .error:
            isPlaybackRequested = false

        default:
            break
        }

        updatePlayPauseButton()
        updateProgressControls()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()

        guard mediaPlayer.state == .playing else {
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
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    private func isSupportedExternalSubtitleURL(_ url: URL) -> Bool {
        let supportedExtensions: Set<String> = [
            "srt",
            "vtt",
            "ass",
            "ssa",
            "sub"
        ]

        return supportedExtensions.contains(url.pathExtension.lowercased())
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
            guard !isScrubbing else {
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

// MARK: - Document Picker Delegate

extension NCVideoVLCViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        loadExternalSubtitle(url: url)
        showControls(animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        showControls(animated: true)
    }
}
