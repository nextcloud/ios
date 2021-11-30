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
import NCCommunication
import MarqueeLabel

class NCSharePaging: UIViewController {

    private let pagingViewController = NCShareHeaderViewController()
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    private var activityEnabled = true
    private var commentsEnabled = true
    private var sharingEnabled = true

    @objc var metadata = tableMetadata()
    var indexPage = NCGlobal.NCSharePagingIndex.activity

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = NCBrandColor.shared.systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done, target: self, action: #selector(exitTapped))

        // Verify Comments & Sharing enabled
        let serverVersionMajor = NCManageDatabase.shared.getCapabilitiesServerInt(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesVersionMajor)
        let comments = NCManageDatabase.shared.getCapabilitiesServerBool(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFilesComments, exists: false)
        if serverVersionMajor >= NCGlobal.shared.nextcloudVersion20 && comments == false {
            commentsEnabled = false
        }
        let sharing = NCManageDatabase.shared.getCapabilitiesServerBool(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesFileSharingApiEnabled, exists: false)
        if sharing == false {
            sharingEnabled = false
        }
        let activity = NCManageDatabase.shared.getCapabilitiesServerArray(account: appDelegate.account, elements: NCElementsJSON.shared.capabilitiesActivity)
        if activity == nil {
            activityEnabled = false
        }
        if indexPage == .sharing && !sharingEnabled {
            indexPage = .activity
        }
        if indexPage == .activity && !activityEnabled && sharingEnabled {
            indexPage = .sharing
        }

        // *** MUST BE THE FIRST ONE ***
        pagingViewController.metadata = metadata

        pagingViewController.activityEnabled = activityEnabled
        pagingViewController.commentsEnabled = commentsEnabled
        pagingViewController.sharingEnabled = sharingEnabled
        pagingViewController.backgroundColor = NCBrandColor.shared.systemBackground
        pagingViewController.menuBackgroundColor = NCBrandColor.shared.systemBackground
        pagingViewController.selectedBackgroundColor = NCBrandColor.shared.systemBackground
        pagingViewController.textColor = NCBrandColor.shared.label
        pagingViewController.selectedTextColor = NCBrandColor.shared.label

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
            pagingViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pagingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pagingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        pagingViewController.dataSource = self
        pagingViewController.delegate = self
        pagingViewController.select(index: indexPage.rawValue)
        let pagingIndexItem = self.pagingViewController(pagingViewController, pagingItemAt: indexPage.rawValue) as! PagingIndexItem
        self.title = pagingIndexItem.title

        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterChangeTheming), object: nil)
        changeTheming()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if appDelegate.disableSharesView {
            self.dismiss(animated: false, completion: nil)
        }

        pagingViewController.menuItemSize = .fixed(
            width: self.view.bounds.width / CGFloat(NCGlobal.NCSharePagingIndex.allCases.count),
            height: 40)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["ocId": metadata.ocId, "serverUrl": metadata.serverUrl])
    }

    @objc func exitTapped() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - NotificationCenter

    @objc func changeTheming() {
        pagingViewController.indicatorColor = NCBrandColor.shared.brandElement
        (pagingViewController.view as! NCSharePagingView).setupConstraints()
        pagingViewController.reloadMenu()
    }
}

// MARK: - PagingViewController Delegate

extension NCSharePaging: PagingViewControllerDelegate {

    func pagingViewController(_ pagingViewController: PagingViewController, willScrollToItem pagingItem: PagingItem, startingViewController: UIViewController, destinationViewController: UIViewController) {

        guard
            let item = pagingItem as? PagingIndexItem,
            let itemIndex = NCGlobal.NCSharePagingIndex(rawValue: item.index)
        else { return }

        if itemIndex == .activity && !activityEnabled {
            pagingViewController.contentInteraction = .none
        } else if itemIndex == .sharing && !sharingEnabled {
            pagingViewController.contentInteraction = .none
        } else {
            self.title = item.title
        }
    }
}

// MARK: - PagingViewController DataSource

extension NCSharePaging: PagingViewControllerDataSource {

    func pagingViewController(_: PagingViewController, viewControllerAt index: Int) -> UIViewController {

        let height = pagingViewController.options.menuHeight + NCSharePagingView.HeaderHeight

        switch NCGlobal.NCSharePagingIndex(rawValue: index) {
        case .activity:
            let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as! NCActivity
            viewController.height = height
            viewController.showComments = true
            viewController.didSelectItemEnable = false
            viewController.metadata = metadata
            viewController.objectType = "files"
            return viewController
        case .sharing:
            let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as! NCShare
            viewController.sharingEnabled = sharingEnabled
            viewController.metadata = metadata
            viewController.height = height
            return viewController
        default:
            return UIViewController()
        }
    }

    func pagingViewController(_: PagingViewController, pagingItemAt index: Int) -> PagingItem {

        switch NCGlobal.NCSharePagingIndex(rawValue: index) {
        case .activity:
            return PagingIndexItem(index: index, title: NSLocalizedString("_activity_", comment: ""))
        case .sharing:
            return PagingIndexItem(index: index, title: NSLocalizedString("_sharing_", comment: ""))
        default:
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
        if NCGlobal.NCSharePagingIndex(rawValue: indexPath.item) == .activity && !activityEnabled {
            return
        } else if NCGlobal.NCSharePagingIndex(rawValue: indexPath.item) == .sharing && !sharingEnabled {
            return
        }
        super.collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

class NCSharePagingView: PagingView {

    static let HeaderHeight: CGFloat = 250
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

        let headerView = Bundle.main.loadNibNamed("NCShareHeaderView", owner: self, options: nil)?.first as! NCShareHeaderView
        headerView.backgroundColor = NCBrandColor.shared.systemBackground
        headerView.ocId = metadata.ocId

        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            headerView.imageView.image = UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))
        } else {
            if metadata.directory {
                let image = UIImage(named: "folder")!
                headerView.imageView.image = image.image(color: NCBrandColor.shared.brandElement, size: image.size.width)
            } else if metadata.iconName.count > 0 {
                headerView.imageView.image = UIImage(named: metadata.iconName)
            } else {
                headerView.imageView.image = UIImage(named: "file")
            }
        }
        headerView.path.text = NCUtilityFileSystem.shared.getPath(metadata: metadata)
        headerView.path.textColor = NCBrandColor.shared.label
        headerView.path.trailingBuffer = headerView.path.frame.width
        if metadata.favorite {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 20), for: .normal)
        } else {
            headerView.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.systemGray, size: 20), for: .normal)
        }
        headerView.info.text = CCUtility.transformedSize(metadata.size) + ", " + CCUtility.dateDiff(metadata.date as Date)
        addSubview(headerView)

        pageView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false

        headerHeightConstraint = headerView.heightAnchor.constraint(
            equalToConstant: NCSharePagingView.HeaderHeight
        )
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
        if let metadata = NCManageDatabase.shared.getMetadataFromOcId(ocId) {
            NCNetworking.shared.favoriteMetadata(metadata) { errorCode, errorDescription in
                if errorCode == 0 {
                    if !metadata.favorite {
                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.yellowFavorite, size: 20), for: .normal)
                    } else {
                        self.favorite.setImage(NCUtility.shared.loadImage(named: "star.fill", color: NCBrandColor.shared.systemGray, size: 20), for: .normal)
                    }
                } else {
                    NCContentPresenter.shared.messageNotification("_error_", description: errorDescription, delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.error, errorCode: errorCode)
                }
            }
        }
    }

    @objc func longTap(sender: UIGestureRecognizer) {

        let board = UIPasteboard.general
        board.string = path.text

        NCContentPresenter.shared.messageNotification("", description: "_copied_path_", delay: NCGlobal.shared.dismissAfterSecond, type: NCContentPresenter.messageType.info, errorCode: NCGlobal.shared.errorNoError)
    }
}
