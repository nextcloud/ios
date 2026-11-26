// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit
import Combine
import NextcloudKit

// MARK: - Media Viewer Hosting Controller

/// Hosts the SwiftUI media viewer inside a UIKit controller.
@MainActor
final class NCMediaViewerHostingController: UIHostingController<NCMediaViewerView>, UIAdaptivePresentationControllerDelegate {
    private let model: NCMediaViewerModel
    private var selectedAppMetadata: tableMetadata? {
        model.selectedMetadata.flatMap { model.appMetadata(for: $0) }
    }
    private let onZoomChanged: (Bool) -> Void
    private let onClose: (_ ocId: String?) -> Void
    private weak var contextMenuController: NCMainTabBarController?

    private var detailHostingController: UIHostingController<NCMediaViewerDetailView>?
    private var detailLoadingTask: Task<Void, Never>?
    private var isShowingDetail = false
    private var detailRequestID: UUID?
    private var detailOcId: String?
    private var cancellables = Set<AnyCancellable>()
    private var transferDelegate: NCMediaViewerTransferDelegate?
    private weak var currentNavigationBar: UINavigationBar?
    private let floatingTitleView = NCMediaViewerFloatingTitleView()

    private var isFoldedMediaLayout = false
    private var localImageInformationKey: String?
    private lazy var adaptiveControlsState = NCMediaAdaptiveControlsState()
    private lazy var adaptiveActionsView = NCMediaAdaptiveActionsView(
        closeAction: UIAction { [weak self] _ in self?.closeButtonTapped() },
        moreButton: NCContextMenuViewer.mediaActionsButton(
            viewController: self,
            metadataProvider: { [weak self] in self?.selectedAppMetadata },
            controllerProvider: { [weak self] in self?.contextMenuController }
        )
    )

    private lazy var floatingTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var moreNavigationItem = NCContextMenuViewer.mediaNavigationItem(
        viewController: self,
        metadataProvider: { [weak self] in self?.selectedAppMetadata },
        controllerProvider: { [weak self] in self?.contextMenuController }
    )

    private lazy var mediaDetailNavigationItem = UIBarButtonItem(
        image: NCUtility().loadImage(named: "info.circle", colors: [NCBrandColor.shared.iconImageColor]),
        style: .plain,
        target: self,
        action: #selector(mediaDetailButtonTapped)
    )

    private lazy var mediaDetailActivityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = NCBrandColor.shared.iconImageColor
        return indicator
    }()

    /// Creates a media viewer hosting controller.
    init(model: NCMediaViewerModel, contextMenuController: NCMainTabBarController?, onZoomChanged: @escaping (Bool) -> Void, onClose: @escaping (_ ocId: String?) -> Void) {
        self.model = model
        self.contextMenuController = contextMenuController
        self.onZoomChanged = onZoomChanged
        self.onClose = onClose

        super.init(
            rootView: NCMediaViewerView(
                model: model,
                contextMenuController: contextMenuController,
                navigationBar: nil,
                onVisibleMetadataChanged: { _ in },
                onZoomChanged: onZoomChanged,
                onClose: { _ in }
            )
        )

        rootView = makeRootView(navigationBar: nil)

        transferDelegate = NCMediaViewerTransferDelegate(
            onDeletedOcId: { [weak self] deletedOcId in
                guard let self else {
                    return
                }

                self.model.markPageAsDeleted(ocId: deletedOcId)
            },
            onReloadDataSource: { [weak self] in
                guard let self else {
                    return
                }

                await self.model.refreshPage(index: self.model.selectedIndex)
            }
        )

        view.backgroundColor = .ncViewerBackground(.system)
        edgesForExtendedLayout = [.all]
        extendedLayoutIncludesOpaqueBars = true
        additionalSafeAreaInsets = .zero

        configureNavigationItem()
        observeModel()
    }

    @MainActor
    @available(*, unavailable)
    dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTitleLabel(metadata: model.selectedMetadata)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let transferDelegate else {
            return
        }

        Task {
            await NCNetworking.shared.transferDispatcher.addDelegate(transferDelegate)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        guard let transferDelegate else {
            return
        }

        Task {
            await NCNetworking.shared.transferDispatcher.removeDelegate(transferDelegate)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateRootViewNavigationBarIfNeeded()
    }

    private func updateRootViewNavigationBarIfNeeded() {
        let navigationBar = navigationController?.navigationBar

        guard currentNavigationBar !== navigationBar else {
            return
        }

        currentNavigationBar = navigationBar
        rootView = makeRootView(navigationBar: navigationBar)
    }

    /// Builds the SwiftUI media viewer root view.
    private func makeRootView(navigationBar: UINavigationBar?) -> NCMediaViewerView {
        NCMediaViewerView(
            model: model,
            contextMenuController: contextMenuController,
            navigationBar: navigationBar,
            onVisibleMetadataChanged: { [weak self] metadata in
                // The pager also calls this from updateUIView. Publish adaptive state
                // only after that SwiftUI update, and discard superseded selections.
                Task { @MainActor [weak self] in
                    guard let self,
                          self.model.selectedMetadata?.ocId == metadata?.ocId,
                          self.model.selectedMetadata?.etag == metadata?.etag else { return }
                    self.updateTitleLabel(metadata: metadata)
                }
            },
            onZoomChanged: onZoomChanged,
            onClose: { [weak self] ocId in
                self?.close(ocId: ocId)
            },
            adaptiveControlsState: NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled ? adaptiveControlsState : nil,
            makeAdaptiveActionsView: NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled ? { [weak self] in
                self?.adaptiveActionsView ?? UIView()
            } : nil,
            onAdaptiveLayoutChanged: { [weak self] isFolded in
                guard let self, NCMediaAdaptiveLayoutConfiguration.isAdaptiveLayoutEnabled else {
                    return
                }
                self.adaptiveLayoutChanged(isFolded)
            }
        )
    }

    private func adaptiveLayoutChanged(_ isFolded: Bool) {
        guard isFoldedMediaLayout != isFolded else {
            return
        }
        closeDetail(animated: false)
        adaptiveControlsState.isFoldedLayout = isFolded
        isFoldedMediaLayout = isFolded
        setChromeHidden(model.isChromeHidden, animated: false)
        updateInformationNavigationItem(metadata: model.selectedMetadata)
        updateLocalAdaptiveImageInformation()
    }

    // MARK: - Closing

    /// Stops media playback before the viewer is closed.
    private func stop() {
        detailRequestID = nil
        localImageInformationKey = nil
        detailLoadingTask?.cancel()
        detailLoadingTask = nil
        setMediaDetailLoading(false)

        // Stop any remaining media playback before releasing the viewer hierarchy.
        // This notification is intentionally global and should only be used for
        // viewer-wide teardown, not for normal page-to-page navigation.
        NotificationCenter.default.post(name: .ncMediaViewerStopPlayback, object: nil)
    }

    /// Closes the viewer, forwarding the selected media identifier when no explicit identifier is provided.
    /// - Parameter ocId: The media identifier that should be used by the caller to resolve the closing animation source frame.
    func close(ocId: String? = nil) {
        let closingOcId = ocId ?? model.selectedMetadata?.ocId

        stop()
        onClose(closingOcId)
    }

    // MARK: - Navigation

    /// Configures the navigation item used by the viewer.
    /// Configures the navigation item used by the viewer.
    private func configureNavigationItem() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = nil
        navigationItem.titleView = floatingTitleView

        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.left"), style: .plain, target: self, action: #selector(closeButtonTapped))

        updateInformationNavigationItem(metadata: model.selectedMetadata)
    }

    /// Info belongs to images only, including when paging between different media types.
    private func updateInformationNavigationItem(metadata: NCMediaViewerItem?) {
        let items = !isFoldedMediaLayout && metadata?.classFile == NKTypeClassFile.image.rawValue ? [moreNavigationItem, mediaDetailNavigationItem] : [moreNavigationItem]
        guard navigationItem.rightBarButtonItems != items else { return }
        navigationItem.rightBarButtonItems = items
    }

    /// Observes model changes and refreshes navigation UI.
    private func observeModel() {
        model.$revision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.isSelectedPageDeleted {
                    self.closeDetail(animated: false)
                    self.localImageInformationKey = nil
                }
                self.updateLocalAdaptiveImageInformation()
            }
            .store(in: &cancellables)

        model.$isChromeHidden
            .receive(on: RunLoop.main)
            .sink { [weak self] isHidden in
                self?.setChromeHidden(isHidden, animated: true)
            }
            .store(in: &cancellables)
    }

    /// Updates the floating title using the current media metadata.
    private func updateTitleLabel(metadata: NCMediaViewerItem?) {
        updateInformationNavigationItem(metadata: metadata)
        guard let metadata else {
            floatingTitleView.clear()
            return
        }

        let primaryTitle = metadata.fileNameView.isEmpty
            ? metadata.fileName
            : metadata.fileNameView

        floatingTitleView.update(primaryText: primaryTitle, secondaryText: floatingTitleSecondaryText(for: metadata))
        if let detailOcId, detailOcId != metadata.ocId {
            closeDetail(animated: false)
        }
        updateLocalAdaptiveImageInformation()
    }

    /// Reads the original once the existing buffer has made it available; never starts a download.
    private func updateLocalAdaptiveImageInformation() {
        guard isFoldedMediaLayout, !isSelectedPageDeleted,
              let metadata = model.selectedMetadata,
              metadata.classFile == NKTypeClassFile.image.rawValue,
              let page = model.selectedPageModel(),
              case .image(_, .some, _, _) = page.state else {
            localImageInformationKey = nil
            if adaptiveControlsState.imageInformation != nil {
                adaptiveControlsState.imageInformation = nil
            }
            return
        }
        let key = "\(metadata.ocId)|\(metadata.etag)"
        guard localImageInformationKey != key else { return }
        localImageInformationKey = key
        model.loader.exif(for: metadata) { [weak self] exif in
            guard let self, self.isFoldedMediaLayout, !self.isSelectedPageDeleted,
                  self.localImageInformationKey == key,
                  self.model.selectedMetadata?.ocId == metadata.ocId else { return }
            self.adaptiveControlsState.imageInformation = (ocId: metadata.ocId, exif: exif)
        }
    }

    /// Builds the secondary floating title text.
    private func floatingTitleSecondaryText(for metadata: NCMediaViewerItem) -> String? {
        floatingTitleDateFormatter.string(from: metadata.date as Date)
    }

    /// Shows or hides the viewer chrome.
    private func setChromeHidden(_ hidden: Bool, animated: Bool) {
        navigationController?.setNavigationBarHidden(hidden || isFoldedMediaLayout, animated: animated)

        UIView.animate(withDuration: animated ? 0.2 : 0, delay: 0, options: [.curveEaseInOut]) {
            self.view.backgroundColor = .ncViewerBackground(ncViewerBackgroundStyle(for: self.model.selectedMetadata, isChromeHidden: hidden))
            self.floatingTitleView.alpha = hidden ? 0 : 1
        }
    }

    @objc
    private func closeButtonTapped() {
        close(ocId: model.selectedMetadata?.ocId)
    }

    @objc
    private func mediaDetailButtonTapped() {
        guard !isSelectedPageDeleted else {
            return
        }

        openDetail(animated: true)
    }

    // MARK: - Detail

    private var isSelectedPageDeleted: Bool {
        guard let page = model.selectedPageModel() else {
            return false
        }

        if case .deleted = page.state {
            return true
        }

        return false
    }

    /// Opens or closes the media detail panel.
    private func openDetail(animated: Bool = true) {
        guard model.selectedMetadata?.classFile == NKTypeClassFile.image.rawValue else { return }
        guard !isShowingDetail else {
            closeDetail(animated: animated)
            return
        }

        guard detailLoadingTask == nil,
              let selectedMetadata = model.selectedMetadata else {
            return
        }

        let selectedOcId = selectedMetadata.ocId
        let index = model.selectedIndex
        let downloadsOriginal = selectedMetadata.classFile == NKTypeClassFile.image.rawValue

        let requestID = UUID()
        detailRequestID = requestID
        detailOcId = selectedOcId
        isShowingDetail = true

        detailLoadingTask = Task { [weak self] in
            guard let self else {
                return
            }

            let metadata = await self.model.loader.metadataForDetails(for: selectedMetadata)
            guard !Task.isCancelled, self.detailRequestID == requestID else { return }

            if downloadsOriginal {
                _ = try? await self.model.downloadOriginalImage(
                    for: metadata,
                    onDownloadStarted: { [weak self] in
                        guard self?.detailRequestID == requestID else { return }
                        self?.setMediaDetailLoading(true)
                    }
                )
            }

            guard self.detailRequestID == requestID else { return }
            guard !Task.isCancelled,
                  self.model.selectedMetadata?.ocId == selectedOcId else {
                self.finishDetailLoadingWithoutPresentation()
                return
            }

            self.detailLoadingTask = nil
            self.setMediaDetailLoading(false)

            self.model.loader.exif(for: metadata) { exif in
                guard self.detailRequestID == requestID,
                      self.isShowingDetail,
                      !self.isSelectedPageDeleted,
                      self.detailHostingController == nil,
                      self.model.selectedMetadata?.ocId == selectedOcId else {
                    return
                }

                self.presentDetailView(metadata: metadata, index: index, exif: exif, animated: animated)
            }
        }
    }

    private func finishDetailLoadingWithoutPresentation() {
        detailRequestID = nil
        detailOcId = nil
        detailLoadingTask = nil
        isShowingDetail = false
        setMediaDetailLoading(false)
    }

    private func setMediaDetailLoading(_ isLoading: Bool) {
        if isLoading {
            mediaDetailActivityIndicator.startAnimating()
            mediaDetailNavigationItem.customView = mediaDetailActivityIndicator
            mediaDetailNavigationItem.isEnabled = false
        } else {
            mediaDetailActivityIndicator.stopAnimating()
            mediaDetailNavigationItem.customView = nil
            mediaDetailNavigationItem.isEnabled = true
        }
    }

    /// Presents the SwiftUI media detail panel.
    private func presentDetailView(metadata: NCMediaViewerItem, index: Int, exif: NCExifData, animated: Bool) {
        let detailView = NCMediaViewerDetailView(metadata: metadata, exif: exif)

        // Only images have inline information. Audio/video keep the standard Info sheet.
        if isFoldedMediaLayout, metadata.classFile == NKTypeClassFile.image.rawValue {
            adaptiveControlsState.imageInformation = (ocId: metadata.ocId, exif: exif)
            adaptiveControlsState.detailView = detailView
            return
        }

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.modalPresentationStyle = .pageSheet

        if let sheetPresentationController = hostingController.sheetPresentationController {
            sheetPresentationController.detents = [.medium(), .large()]
            sheetPresentationController.prefersGrabberVisible = true
            sheetPresentationController.preferredCornerRadius = 24
            sheetPresentationController.prefersEdgeAttachedInCompactHeight = true
            sheetPresentationController.widthFollowsPreferredContentSizeWhenEdgeAttached = false
        }

        detailHostingController = hostingController
        hostingController.presentationController?.delegate = self

        present(hostingController, animated: animated)
    }

    /// Closes the media detail panel.
    private func closeDetail(animated: Bool = true) {
        detailRequestID = nil
        detailOcId = nil
        isShowingDetail = false
        detailLoadingTask?.cancel()
        detailLoadingTask = nil
        setMediaDetailLoading(false)

        adaptiveControlsState.detailView = nil
        adaptiveControlsState.imageInformation = nil

        guard let detailHostingController else {
            isShowingDetail = false
            return
        }

        detailHostingController.dismiss(animated: animated) { [weak self] in
            self?.detailHostingController = nil
            self?.isShowingDetail = false
        }
    }

    /// Resets the detail state when the sheet is dismissed interactively.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        detailRequestID = nil
        detailOcId = nil
        detailHostingController = nil
        isShowingDetail = false
    }

    /// Marks the selected media item as deleted.
    @MainActor
    func markCurrentItemAsDeleted() {
        guard let metadata = model.selectedMetadata else {
            return
        }

        model.markPageAsDeleted(ocId: metadata.ocId)
    }

    /// Marks a specific media item as deleted.
    @MainActor
    func markItemAsDeleted(ocId: String) {
        model.markPageAsDeleted(ocId: ocId)
    }

    /// Downloads the original of a photo for editing.
    /// Returns `true` only if the viewer is still on screen and showing that photo once the download finishes.
    func downloadOriginalForEditing(_ metadata: tableMetadata) async -> Bool {
        do {
            try await model.downloadOriginalImage(for: model.viewerItem(from: metadata))
        } catch {
            return false
        }
        return viewIfLoaded?.window != nil && model.selectedMetadata?.ocId == metadata.ocId
    }
}

// MARK: - Media Viewer Transfer Delegate

/// Bridges transfer events into the MainActor-isolated media viewer controller.
final class NCMediaViewerTransferDelegate: NSObject, NCTransferDelegate {
    private let onDeletedOcId: @MainActor (_ ocId: String) -> Void
    private let onReloadDataSource: @MainActor () async -> Void
    let sceneIdentifier: String = ""

    init(onDeletedOcId: @escaping @MainActor (_ ocId: String) -> Void, onReloadDataSource: @escaping @MainActor () async -> Void) {
        self.onDeletedOcId = onDeletedOcId
        self.onReloadDataSource = onReloadDataSource
    }

    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(serverUrl: String?, requestData: Bool, status: Int?) {
        Task { @MainActor in
            await onReloadDataSource()
        }
    }

    func transferProgressDidUpdate(progress: Float, totalBytes: Int64, totalBytesExpected: Int64, fileName: String, serverUrl: String) { }

    func transferChange(networkingStatus: String, account: String, fileName: String, serverUrl: String, selector: String?, ocId: String, destination: String?, error: NKError) {
        guard networkingStatus == NCGlobal.shared.networkingStatusDelete,
              error == .success else {
            return
        }

        Task { @MainActor in
            onDeletedOcId(ocId)
        }
    }
}
