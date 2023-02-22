//
//  NCSharePaging.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 25/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import Parchment
import NextcloudKit
import MarqueeLabel

protocol NCSharePagingContent {
    var textField: UITextField? { get }
}

class NCSharePaging: UIViewController {

    private let pagingViewController = NCShareHeaderViewController()
    private weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    private var activityEnabled = true
    private var commentsEnabled = true
    private var sharingEnabled = true
    private var currentVC: NCSharePagingContent?

    @objc var metadata = tableMetadata()
    var indexPage = NCGlobal.NCSharePagingIndex.activity

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done, target: self, action: #selector(exitTapped))
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        setupCapabilities()

        // *** MUST BE THE FIRST ONE ***
        pagingViewController.metadata = metadata

        pagingViewController.activityEnabled = activityEnabled
        pagingViewController.commentsEnabled = commentsEnabled
        pagingViewController.sharingEnabled = sharingEnabled
        pagingViewController.backgroundColor = .systemBackground
        pagingViewController.menuBackgroundColor = .systemBackground
        pagingViewController.selectedBackgroundColor = .systemBackground
        pagingViewController.textColor = .label
        pagingViewController.selectedTextColor = .label

        // Pagination
        addChild(pagingViewController)
        view.addSubview(pagingViewController.view)
        pagingViewController.didMove(toParent: self)

        // Customization
        pagingViewController.indicatorOptions = .visible(
            height: 1,
            zIndex: Int.max,
            spacing: .zero,
            insets: UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        )

        // Contrain the paging view to all edges.
        pagingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pagingViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pagingViewController.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pagingViewController.view.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            pagingViewController.view.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
        ])

        pagingViewController.dataSource = self
        pagingViewController.delegate = self
        pagingViewController.select(index: indexPage.rawValue)
        let pagingIndexItem = self.pagingViewController(pagingViewController, pagingItemAt: indexPage.rawValue) as? PagingIndexItem
        self.title = pagingIndexItem?.title

        NotificationCenter.default.addObserver(self, selector: #selector(self.orientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)

        if sharingEnabled {
            pagingViewController.indicatorColor = NCBrandColor.shared.brandElement
        } else {
            pagingViewController.indicatorColor = .clear
        }
        (pagingViewController.view as? NCSharePagingView)?.setupConstraints()
        pagingViewController.reloadMenu()
    }

    func setupCapabilities() {
        guard let appDelegate = appDelegate else { return }

        // Verify Comments & Sharing enabled
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        let comments = NCManageDatabase.shared.getCapabilitiesServerBool(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFilesComments, exists: false)
        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion20 && comments == false {
            commentsEnabled = false
        }
        sharingEnabled = metadata.isSharable
        let activity = NCManageDatabase.shared.getCapabilitiesServerArray(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesActivity)
        activityEnabled = activity != nil
        if indexPage == .sharing && !sharingEnabled {
            indexPage = .activity
        }
        if indexPage == .activity && !activityEnabled && sharingEnabled {
            indexPage = .sharing
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        currentVC = pagingViewController.pageViewController.selectedViewController as? NCSharePagingContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if appDelegate?.disableSharesView == true {
            self.dismiss(animated: false, completion: nil)
        }

        pagingViewController.menuItemSize = .fixed(
            width: self.view.bounds.width / CGFloat(NCGlobal.NCSharePagingIndex.allCases.count),
            height: 40)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - NotificationCenter

    @objc func orientationDidChange() {
        pagingViewController.menuItemSize = .fixed(
            width: self.view.bounds.width / CGFloat(NCGlobal.NCSharePagingIndex.allCases.count),
            height: 40)
        currentVC?.textField?.resignFirstResponder()
    }

    // MARK: - Keyboard & TextField
    @objc func keyboardWillShow(notification: Notification) {
         let frameEndUserInfoKey = UIResponder.keyboardFrameEndUserInfoKey

         guard let info = notification.userInfo,
               let textField = currentVC?.textField,
               let centerObject = textField.superview?.convert(textField.center, to: nil),
               let keyboardFrame = info[frameEndUserInfoKey] as? CGRect
         else { return }

        let diff = keyboardFrame.origin.y - centerObject.y - textField.frame.height
         if diff < 0 {
             view.frame.origin.y = diff
         }
     }

     @objc func keyboardWillHide(notification: NSNotification) {
         view.frame.origin.y = 0
     }

    @objc func exitTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - PagingViewController Delegate

extension NCSharePaging: PagingViewControllerDelegate {

    func pagingViewController(_ pagingViewController: PagingViewController, willScrollToItem pagingItem: PagingItem, startingViewController: UIViewController, destinationViewController: UIViewController) {

        guard
            let item = pagingItem as? PagingIndexItem,
            let itemIndex = NCGlobal.NCSharePagingIndex(rawValue: item.index)
        else { return }

        if itemIndex == .activity && !activityEnabled || itemIndex == .sharing && !sharingEnabled {
            pagingViewController.contentInteraction = .none
        } else {
            self.title = item.title
        }

        currentVC?.textField?.resignFirstResponder()
        self.currentVC = destinationViewController as? NCSharePagingContent
    }
}

// MARK: - PagingViewController DataSource

extension NCSharePaging: PagingViewControllerDataSource {

    func pagingViewController(_: PagingViewController, viewControllerAt index: Int) -> UIViewController {

        let height = pagingViewController.options.menuHeight + NCSharePagingView.headerHeight

        switch NCGlobal.NCSharePagingIndex(rawValue: index) {
        case .activity:
            guard let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as? NCActivity else {
                return UIViewController()
            }
            viewController.height = height
            viewController.showComments = true
            viewController.didSelectItemEnable = false
            viewController.metadata = metadata
            viewController.objectType = "files"
            return viewController
        case .sharing:
            guard let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as? NCShare else {
                return UIViewController()
            }
            viewController.sharingEnabled = sharingEnabled
            viewController.metadata = metadata
            viewController.height = height
            return viewController
        default:
            return UIViewController()
        }
    }

    func pagingViewController(_: PagingViewController, pagingItemAt index: Int) -> PagingItem {

        if sharingEnabled {
            switch NCGlobal.NCSharePagingIndex(rawValue: index) {
            case .activity:
                return PagingIndexItem(index: index, title: NSLocalizedString("_activity_", comment: ""))
            case .sharing:
                return PagingIndexItem(index: index, title: NSLocalizedString("_sharing_", comment: ""))
            default:
                return PagingIndexItem(index: index, title: "")
            }
        } else {
            self.title = NSLocalizedString("_activity_", comment: "")
            return PagingIndexItem(index: index, title: "")
        }
    }

    func numberOfViewControllers(in pagingViewController: PagingViewController) -> Int {
        return 2
    }
}

// MARK: - Header

class NCShareHeaderViewController: PagingViewController {

    public var image: UIImage?
    public var metadata = tableMetadata()

    public var activityEnabled = true
    public var commentsEnabled = true
    public var sharingEnabled = true

    override func loadView() {
        view = NCSharePagingView(
            options: options,
            collectionView: collectionView,
            pageView: pageViewController.view,
            metadata: metadata
        )
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard NCGlobal.NCSharePagingIndex(rawValue: indexPath.item) != .activity || activityEnabled,
              NCGlobal.NCSharePagingIndex(rawValue: indexPath.item) != .sharing || sharingEnabled
        else { return }
        super.collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

class NCSharePagingView: PagingView {

    static let headerHeight: CGFloat = 100
    var metadata = tableMetadata()

    var headerHeightConstraint: NSLayoutConstraint?

    // MARK: - View Life Cycle

    public init(options: Parchment.PagingOptions, collectionView: UICollectionView, pageView: UIView, metadata: tableMetadata) {
        super.init(options: options, collectionView: collectionView, pageView: pageView)

        self.metadata = metadata
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupConstraints() {

        guard let headerView = Bundle.main.loadNibNamed("NCShareHeaderView", owner: self, options: nil)?.first as? NCShareHeaderView else { return }
        headerView.backgroundColor = .systemBackground
        headerView.ocId = metadata.ocId

        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            headerView.imageView.image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
        } else {
            if metadata.directory {
                let image = metadata.e2eEncrypted ? UIImage(named: "folderEncrypted") : UIImage(named: "folder")
                headerView.imageView.image = image?.image(color: NCBrandColor.shared.brandElement, size: image?.size.width ?? 0)
                headerView.imageView.image = headerView.imageView.image?.colorizeFolder(metadata: metadata)
            } else if !metadata.iconName.isEmpty {
                headerView.imageView.image = UIImage(named: metadata.iconName)
            } else {
                headerView.imageView.image = UIImage(named: "file")
            }
        }
        headerView.path.text = NCUtilityFileSystem.shared.getPath(path: metadata.path, user: metadata.user, fileName: metadata.fileName)
        headerView.path.textColor = .label
        headerView.path.trailingBuffer = headerView.path.frame.width
        if metadata.favorite {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 20), for: .normal)
        } else {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: .systemGray, size: 20), for: .normal)
        }
        headerView.info.text = CCUtility.transformedSize(metadata.size) + ", " + CCUtility.dateDiff(metadata.date as Date)
        addSubview(headerView)

        pageView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false

        headerHeightConstraint = headerView.heightAnchor.constraint(equalToConstant: NCSharePagingView.headerHeight)
        headerHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: options.menuHeight),
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),

            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),

            pageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pageView.topAnchor.constraint(equalTo: topAnchor, constant: 10)
        ])
    }
}

class NCShareHeaderView: UIView {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var path: MarqueeLabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var favorite: UIButton!
    var ocId = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(self.longTap))
        path.addGestureRecognizer(longGesture)
    }

    @IBAction func touchUpInsideFavorite(_ sender: UIButton) {
        guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) else { return }
        NCNetworking.shared.favoriteMetadata(metadata) { error in
            if error == .success {
                self.favorite.setImage(NCUtility.shared.loadImage(
                    named: "star.fill",
                    color: metadata.favorite ? NCBrandColor.shared.yellowFavorite : .systemGray,
                    size: 20), for: .normal)
            } else {
                NCContentPresenter.shared.showError(error: error)
            }
        }
    }

    @objc func longTap(sender: UIGestureRecognizer) {
        UIPasteboard.general.string = path.text
        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_copied_path_")
        NCContentPresenter.shared.showInfo(error: error)
    }
}
