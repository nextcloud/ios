// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import UIKit
import SwiftUI
import MobileVLCKit
import NextcloudKit
import UniformTypeIdentifiers

// MARK: - VLC View Controller

/// UIKit-only VLC video controller.
///
/// This controller is intentionally outside the SwiftUI paging hierarchy.
/// It owns one stable drawable view, one VLCMediaPlayer, and one shared controls view.
final class NCVideoVLCViewController: UIViewController {

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

    internal let drawableView = UIView()
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

    // MARK: - VLC

    internal let mediaPlayer = VLCMediaPlayer()
    private var externalSubtitleURL: URL?

    internal var progressTimer: Timer?
    internal var controlsHideTimer: Timer?
    internal var controlsVisible = false
    internal var isScrubbing = false

    internal var shouldKeepControlsVisible: Bool {
        mediaPlayer.state != .playing && !mediaPlayer.isPlaying
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
        mediaPlayer.delegate = nil
        stop()
    }

    // MARK: - Lifecycle

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .black
        rootView.isOpaque = true
        rootView.clipsToBounds = true

        drawableView.backgroundColor = .black
        drawableView.isOpaque = true
        drawableView.clipsToBounds = true
        drawableView.translatesAutoresizingMaskIntoConstraints = false

        previewImageView.backgroundColor = .black
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        updatePreviewImage()

        controlsView.delegate = self
        controlsView.setTopActionsMode(.vlcTracks)
        controlsView.alpha = 0
        controlsView.isHidden = true
        controlsView.translatesAutoresizingMaskIntoConstraints = false

        rootView.addSubview(drawableView)
        rootView.addSubview(previewImageView)
        rootView.addSubview(controlsView)

        NSLayoutConstraint.activate([
            drawableView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            drawableView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            drawableView.topAnchor.constraint(equalTo: rootView.topAnchor),
            drawableView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            previewImageView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            previewImageView.topAnchor.constraint(equalTo: rootView.topAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

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

        view.backgroundColor = .black

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
            self?.attachDrawable()
            self?.updateControlsNavigationBar()
            self?.configureFloatingTitleViewIfNeeded()
        })
    }

    // MARK: - Public API

    /// Updates the current VLC input.
    ///
    /// If the URL changes, the current media is stopped and the new media is prepared.
    /// The context menu is refreshed for the new metadata.
    ///
    /// - Parameters:
    ///   - metadata: Updated video metadata.
    ///   - url: Updated playable URL.
    ///   - previewURL: Optional local preview image URL shown until VLC starts rendering.
    ///   - userAgent: Optional HTTP User-Agent.
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
        refreshVLCTrackMenuItemsWhenPlayerIsActive()

        refreshMoreMenu()

        if urlChanged {
            start()
        }

        updatePlayPauseButton()
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

    /// Builds the VLC-specific More menu.
    ///
    /// The menu uses `sender: self`, so menu actions present from the visible
    /// VLC controller instead of the SwiftUI viewer underneath.
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
        stopProgressTimer()
        stop()

        NCVideoVLCPresenter.clearCurrent(self)

        dismiss(animated: false) { [onClose, metadata] in
            DispatchQueue.main.async {
                onClose?(metadata.ocId)
            }
        }
    }

    func closeImmediately() {
        stopControlsHideTimer()
        stopProgressTimer()
        stop()

        NCVideoVLCPresenter.clearCurrent(self)

        dismiss(animated: false) { [onClose] in
            onClose?(nil)
        }
    }

    // MARK: - Swipe Navigation

    /// Configures UIKit swipe gestures for media navigation and viewer closing.
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

        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
        view.addGestureRecognizer(closePanGesture)
    }

    /// Configures a single tap gesture to toggle VLC playback controls.
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

    /// Handles single taps by toggling the VLC playback controls.
    ///
    /// Taps are ignored while playback is not running because controls and the
    /// navigation bar must remain visible in prepared, paused, and stopped states.
    ///
    /// - Parameter gesture: Source tap gesture recognizer.
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

    /// Handles horizontal VLC swipe gestures.
    ///
    /// Left moves to the next media item when available.
    /// Right moves to the previous media item when available.
    /// The controller itself does not know the media list; it only forwards the intent
    /// through callbacks owned by the presenter/viewer layer.
    ///
    /// - Parameter gesture: Source swipe gesture recognizer.
    @objc
    private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
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

    /// Handles downward pan gestures by closing the VLC viewer.
    ///
    /// This mirrors the common media viewer drag-to-close behavior: a short downward
    /// drag or a quick downward flick is enough, while horizontal paging still wins
    /// when the gesture is mostly horizontal.
    ///
    /// - Parameter gesture: Source pan gesture recognizer.
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

    /// Prepares VLC playback without starting it automatically.
    private func start() {
        attachDrawable()
        showPreviewImage()

        let media = VLCMedia(url: url)

        if let userAgent,
           !userAgent.isEmpty,
           !url.isFileURL {
            media.addOption(":http-user-agent=\(userAgent)")
        }

        mediaPlayer.media = media
        updatePlayPauseButton()
        updateProgressControls()
        clearVLCTrackMenuItems()
        startProgressTimer()
        showControls(animated: false)
        stopControlsHideTimer()

        nkLog(
            tag: NCGlobal.shared.logTagViewer,
            emoji: .debug,
            message: "VIDEO VLC UIKit prepared without autoplay ocId \(metadata.ocId), url \(url.absoluteString)",
            consoleOnly: true
        )
    }

    /// Stops VLC playback and releases resources.
    private func stop() {
        mediaPlayer.stop()
        mediaPlayer.media = nil
        mediaPlayer.drawable = nil
        externalSubtitleURL = nil
        showPreviewImage()
        stopProgressTimer()
        updatePlayPauseButton()
        updateProgressControls()
        clearVLCTrackMenuItems()
    }

    /// Attaches the drawable view to VLC.
    private func attachDrawable() {
        guard drawableView.bounds.width > 0,
              drawableView.bounds.height > 0 else {
            return
        }

        mediaPlayer.drawable = drawableView
        if mediaPlayer.isPlaying {
            hidePreviewImage()
        }
    }

    /// Handles VLC playback state changes.
    private func handleMediaPlayerStateChange() {
        updatePlayPauseButton()
        updateProgressControls()
        refreshVLCTrackMenuItemsWhenPlayerIsActive()

        guard mediaPlayer.state == .playing else {
            showControls(animated: false)
            stopControlsHideTimer()
            return
        }

        scheduleControlsHideIfNeededAfterPlaybackStart()
    }

    /// Arms the controls auto-hide timer when VLC is confirmed to be playing.
    ///
    /// VLC state notifications and `isPlaying` may not become true at exactly the same
    /// time. This helper is safe to call from both state and time callbacks because it
    /// does not restart an already scheduled timer.
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

        hidePreviewImage()
        scheduleControlsHide()
    }

    // MARK: - VLC Track Menus

    /// Refreshes the SwiftUI track menus using the current VLC player state.
    func refreshVLCTrackMenuItems() {
        controlsView.setSubtitleTrackMenuItems(makeSubtitleTrackMenuItems())
        controlsView.setAudioTrackMenuItems(makeAudioTrackMenuItems())
    }

    /// Clears the SwiftUI track menus while VLC has not exposed media tracks yet.
    func clearVLCTrackMenuItems() {
        controlsView.setSubtitleTrackMenuItems([])
        controlsView.setAudioTrackMenuItems([])
    }

    /// Refreshes the SwiftUI track menus only when VLC is active enough to expose tracks.
    func refreshVLCTrackMenuItemsWhenPlayerIsActive() {
        switch mediaPlayer.state {
        case .opening, .buffering, .playing, .paused:
            refreshVLCTrackMenuItems()
        default:
            clearVLCTrackMenuItems()
        }
    }

    /// Selects a VLC subtitle track and persists the selection for the current metadata.
    ///
    /// - Parameter index: VLC subtitle track index selected by the user.
    func selectSubtitleTrack(index: Int32) {
        mediaPlayer.currentVideoSubTitleIndex = index
        NCManageDatabase.shared.addVideo(
            metadata: metadata,
            currentVideoSubTitleIndex: Int(index)
        )
        refreshVLCTrackMenuItems()
    }

    /// Selects a VLC audio track and persists the selection for the current metadata.
    ///
    /// - Parameter index: VLC audio track index selected by the user.
    func selectAudioTrack(index: Int32) {
        mediaPlayer.currentAudioTrackIndex = index
        NCManageDatabase.shared.addVideo(
            metadata: metadata,
            currentAudioTrackIndex: Int(index)
        )
        refreshVLCTrackMenuItems()
    }

    /// Presents a document picker that lets the user select an external subtitle file for VLC playback.
    func presentExternalSubtitlePicker() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.item],
            asCopy: true
        )
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    /// Returns whether the selected file extension is supported as an external subtitle.
    ///
    /// - Parameter url: File URL selected by the user.
    /// - Returns: True when VLC should try to load the file as an external subtitle.
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

    /// Loads an external subtitle file into the current VLC media player.
    ///
    /// - Parameter url: Local subtitle file URL selected by the user.
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

    /// Copies the selected subtitle to a stable temporary file that VLC can read.
    ///
    /// - Parameter url: Security-scoped or temporary document picker URL.
    /// - Returns: Local temporary file URL used by VLC.
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

    /// Refreshes VLC subtitle tracks after VLC has had time to register the external subtitle file.
    private func refreshExternalSubtitleTracksAfterLoad() {
        refreshVLCTrackMenuItems()

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            self?.refreshVLCTrackMenuItems()
        }
    }

    /// Builds subtitle menu items from VLC subtitle tracks.
    ///
    /// - Returns: Subtitle menu items rendered by the shared SwiftUI controls.
    private func makeSubtitleTrackMenuItems() -> [NCVideoTrackMenuItem] {
        makeTrackMenuItems(
            titles: mediaPlayer.videoSubTitlesNames,
            indexes: mediaPlayer.videoSubTitlesIndexes,
            currentIndex: currentSubtitleTrackIndex()
        )
    }

    /// Builds audio menu items from VLC audio tracks.
    ///
    /// - Returns: Audio menu items rendered by the shared SwiftUI controls.
    private func makeAudioTrackMenuItems() -> [NCVideoTrackMenuItem] {
        makeTrackMenuItems(
            titles: mediaPlayer.audioTrackNames,
            indexes: mediaPlayer.audioTrackIndexes,
            currentIndex: currentAudioTrackIndex()
        )
    }

    /// Returns the persisted subtitle track index, falling back to VLC's current subtitle track index.
    ///
    /// - Returns: Current subtitle track index used to mark the selected menu item.
    private func currentSubtitleTrackIndex() -> Int? {
        if let data = NCManageDatabase.shared.getVideo(metadata: metadata),
           let currentVideoSubTitleIndex = data.currentVideoSubTitleIndex {
            return currentVideoSubTitleIndex
        }

        return Int(mediaPlayer.currentVideoSubTitleIndex)
    }

    /// Returns the persisted audio track index, falling back to VLC's current audio track index.
    ///
    /// - Returns: Current audio track index used to mark the selected menu item.
    private func currentAudioTrackIndex() -> Int? {
        if let data = NCManageDatabase.shared.getVideo(metadata: metadata),
           let currentAudioTrackIndex = data.currentAudioTrackIndex {
            return currentAudioTrackIndex
        }

        return Int(mediaPlayer.currentAudioTrackIndex)
    }

    /// Builds SwiftUI menu items from VLC track names and indexes.
    ///
    /// - Parameters:
    ///   - titles: VLC track titles.
    ///   - indexes: VLC track indexes.
    ///   - currentIndex: Currently selected VLC track index.
    /// - Returns: Track menu items with selection state.
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

    /// Normalizes a VLC track index to Int32.
    ///
    /// - Parameters:
    ///   - indexes: VLC track indexes returned by MobileVLCKit.
    ///   - index: Position to read.
    /// - Returns: Normalized VLC track index, if available.
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

    /// Updates the fullscreen preview image shown before VLC starts rendering video.
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

    /// Shows the preview image while VLC prepares the first rendered frame.
    private func showPreviewImage() {
        guard previewImageView.image != nil else {
            previewImageView.isHidden = true
            return
        }

        previewImageView.layer.removeAllAnimations()
        previewImageView.alpha = 1
        previewImageView.isHidden = false
    }

    /// Hides the preview image after VLC starts rendering playback.
    private func hidePreviewImage() {
        guard !previewImageView.isHidden else {
            return
        }

        previewImageView.layer.removeAllAnimations()
        previewImageView.alpha = 0
        previewImageView.isHidden = true
    }

    /// Updates the shared controls top actions reference using the real navigation bar.
    private func updateControlsNavigationBar() {
        controlsView.setTopActionsNavigationBar(navigationController?.navigationBar)
    }

    /// Returns whether a point is inside one of the visible controls areas.
    ///
    /// - Parameter location: Point in this controller's root view coordinate space.
    /// - Returns: True when the point is inside top action, center, or bottom controls.
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
    /// Allows tap and swipe gestures to coexist with VLC's drawable view and UIKit controls.
    ///
    /// - Parameters:
    ///   - gestureRecognizer: Gesture recognizer asking for simultaneous recognition.
    ///   - otherGestureRecognizer: Other gesture recognizer involved in the decision.
    /// - Returns: True to avoid VLC/touch handling from suppressing viewer gestures.
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

// MARK: - Document Picker Delegate

extension NCVideoVLCViewController: UIDocumentPickerDelegate {
    /// Handles the selected external subtitle file and attaches it to the VLC player.
    ///
    /// - Parameters:
    ///   - controller: Document picker controller.
    ///   - urls: Selected file URLs.
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        loadExternalSubtitle(url: url)
        showControls(animated: true)
    }

    /// Handles document picker cancellation.
    ///
    /// - Parameter controller: Document picker controller.
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        showControls(animated: true)
    }
}
