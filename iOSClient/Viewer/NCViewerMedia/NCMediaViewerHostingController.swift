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
    private let onZoomChanged: (Bool) -> Void
    private let onClose: (_ ocId: String?) -> Void
    private weak var contextMenuController: NCMainTabBarController?

    private var detailHostingController: UIHostingController<NCMediaViewerDetailView>?
    private var isShowingDetail = false
    private var cancellables = Set<AnyCancellable>()
    private var transferDelegate: NCMediaViewerTransferDelegate?
    private weak var currentNavigationBar: UINavigationBar?
    private let floatingTitleView = NCMediaViewerFloatingTitleView()

    private lazy var floatingTitleDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private lazy var moreNavigationItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            image: NCImageCache.shared.getImageButtonMore(),
            primaryAction: nil,
            menu: nil
        )

        item.menu = UIMenu(title: "", children: [
            UIDeferredMenuElement.uncached { [weak self, weak item] completion in
                guard let self,
                      let metadata = self.model.selectedMetadata else {
                    completion([])
                    return
                }

                if let menu = NCContextMenuViewer(
                    metadata: metadata,
                    controller: self.contextMenuController,
                    viewController: self,
                    webView: false,
                    sender: item
                ).viewMenu() {
                    completion(menu.children)
                } else {
                    completion([])
                }
            }
        ])

        return item
    }()

    private lazy var mediaDetailNavigationItem = UIBarButtonItem(
        image: NCUtility().loadImage(
            named: "info.circle",
            colors: [NCBrandColor.shared.iconImageColor]
        ),
        style: .plain,
        target: self,
        action: #selector(mediaDetailButtonTapped)
    )

    /// Creates a media viewer hosting controller.
    init(
        model: NCMediaViewerModel,
        contextMenuController: NCMainTabBarController?,
        onZoomChanged: @escaping (Bool) -> Void,
        onClose: @escaping (_ ocId: String?) -> Void
    ) {
        self.model = model
        self.contextMenuController = contextMenuController
        self.onZoomChanged = onZoomChanged
        self.onClose = onClose

        super.init(
            rootView: NCMediaViewerView(
                model: model,
                contextMenuController: contextMenuController,
                navigationBar: nil,
                onVisibleMetadataChanged: { _, _ in },
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

                await self.model.reloadPage(index: self.model.selectedIndex)
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

        updateTitleLabel(
            metadata: model.selectedMetadata,
            backgroundColor: .ncViewerBackground(.system)
        )
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
        configureFloatingTitleViewIfNeeded()
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
            onVisibleMetadataChanged: { [weak self] metadata, backgroundColor in
                self?.updateTitleLabel(
                    metadata: metadata,
                    backgroundColor: backgroundColor
                )
            },
            onZoomChanged: onZoomChanged,
            onClose: { [weak self] ocId in
                self?.close(ocId: ocId)
            }
        )
    }

    // MARK: - Closing

    /// Stops media playback before the viewer is closed.
    private func stop() {
        // Stop any remaining media playback before releasing the viewer hierarchy.
        // This notification is intentionally global and should only be used for
        // viewer-wide teardown, not for normal page-to-page navigation.
        NotificationCenter.default.post(
            name: .ncMediaViewerStopPlayback,
            object: nil
        )
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
    private func configureNavigationItem() {
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = nil
        navigationItem.titleView = nil

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )

        navigationItem.rightBarButtonItems = [
            moreNavigationItem,
            mediaDetailNavigationItem
        ]
    }

    /// Observes model changes and refreshes navigation UI.
    private func observeModel() {
        model.$isChromeHidden
            .receive(on: RunLoop.main)
            .sink { [weak self] isHidden in
                self?.setChromeHidden(isHidden, animated: true)
            }
            .store(in: &cancellables)
    }

    /// Configures the floating title view inside the navigation bar chrome.
    private func configureFloatingTitleViewIfNeeded() {
        guard let navigationBar = navigationController?.navigationBar else {
            return
        }

        floatingTitleView.attach(to: navigationBar)
    }

    /// Updates the floating title using the current media metadata.
    private func updateTitleLabel(
        metadata: tableMetadata?,
        backgroundColor: UIColor
    ) {
        guard let metadata else {
            floatingTitleView.clear()
            return
        }

        let primaryTitle = metadata.fileNameView.isEmpty
            ? metadata.fileName
            : metadata.fileNameView

        floatingTitleView.update(
            primaryText: primaryTitle,
            secondaryText: floatingTitleSecondaryText(for: metadata)
        )
    }

    /// Returns a readable title color for the current background.
    private func floatingTitleTextColor(for backgroundColor: UIColor) -> UIColor {
        let resolvedColor = backgroundColor.resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard resolvedColor.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return .white
        }

        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance < 0.5 ? .white : .black
    }

    /// Builds the secondary floating title text.
    private func floatingTitleSecondaryText(for metadata: tableMetadata) -> String? {
        floatingTitleDateFormatter.string(from: metadata.date as Date)
    }

    /// Shows or hides the viewer chrome.
    private func setChromeHidden(_ hidden: Bool, animated: Bool) {
        navigationController?.setNavigationBarHidden(
            hidden,
            animated: animated
        )

        UIView.animate(
            withDuration: animated ? 0.2 : 0,
            delay: 0,
            options: [.curveEaseInOut]
        ) {
            self.view.backgroundColor = hidden
                ? .black
                : .ncViewerBackground(.system)
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
        Task {
            guard !isShowingDetail else {
                closeDetail(animated: animated)
                return
            }

            guard var metadata = model.selectedMetadata else {
                return
            }
            metadata = await NCNetworking.shared.updateMetadataPlaceholder(metadata)

            let index = model.selectedIndex
            isShowingDetail = true

            NCUtility().getExif(metadata: metadata) { [weak self] exif in
                Task { @MainActor in
                    guard let self else {
                        return
                    }

                    self.presentDetailView(
                        metadata: metadata,
                        index: index,
                        exif: exif,
                        animated: animated
                    )
                }
            }
        }
    }

    /// Presents the SwiftUI media detail panel.
    private func presentDetailView(
        metadata: tableMetadata,
        index: Int,
        exif: ExifData,
        animated: Bool
    ) {
        let detailView = NCMediaViewerDetailView(
            metadata: metadata,
            exif: exif
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

        detailHostingController = hostingController
        hostingController.presentationController?.delegate = self

        present(hostingController, animated: animated)
    }

    /// Closes the media detail panel.
    private func closeDetail(animated: Bool = true) {
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
}

// MARK: - Media Viewer Transfer Delegate

/// Bridges transfer events into the MainActor-isolated media viewer controller.
final class NCMediaViewerTransferDelegate: NSObject, NCTransferDelegate {
    private let onDeletedOcId: @MainActor (_ ocId: String) -> Void
    private let onReloadDataSource: @MainActor () async -> Void
    let sceneIdentifier: String = ""

    init(
        onDeletedOcId: @escaping @MainActor (_ ocId: String) -> Void,
        onReloadDataSource: @escaping @MainActor () async -> Void
    ) {
        self.onDeletedOcId = onDeletedOcId
        self.onReloadDataSource = onReloadDataSource
    }

    func transferReloadData(serverUrl: String?) { }

    func transferReloadDataSource(
        serverUrl: String?,
        requestData: Bool,
        status: Int?
    ) {
        Task { @MainActor in
            await onReloadDataSource()
        }
    }

    func transferProgressDidUpdate(
        progress: Float,
        totalBytes: Int64,
        totalBytesExpected: Int64,
        fileName: String,
        serverUrl: String
    ) { }

    func transferChange(
        networkingStatus: String,
        account: String,
        fileName: String,
        serverUrl: String,
        selector: String?,
        ocId: String,
        destination: String?,
        error: NKError
    ) {
        guard networkingStatus == NCGlobal.shared.networkingStatusDelete,
              error == .success else {
            return
        }

        Task { @MainActor in
            onDeletedOcId(ocId)
        }
    }
}
