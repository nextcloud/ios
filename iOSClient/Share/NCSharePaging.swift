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
import TagListView

protocol NCSharePagingContent {
    var textField: UITextField? { get }
}

class NCSharePaging: UIViewController {

    private let pagingViewController = NCShareHeaderViewController()
    private weak var appDelegate = UIApplication.shared.delegate as? AppDelegate

    private var currentVC: NCSharePagingContent?
    private let applicationHandle = NCApplicationHandle()

    var metadata = tableMetadata()
    var pages: [NCBrandOptions.NCInfoPagingTab] = []
    var page: NCBrandOptions.NCInfoPagingTab = .activity

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = NSLocalizedString("_details_", comment: "")

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .done, target: self, action: #selector(exitTapped))
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterApplicationDidEnterBackground), object: nil)

        // *** MUST BE THE FIRST ONE ***
        pagingViewController.metadata = metadata
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

        if page.rawValue < pages.count {
            pagingViewController.select(index: page.rawValue)
        } else {
            pagingViewController.select(index: 0)
        }
       
        (pagingViewController.view as? NCSharePagingView)?.setupConstraints()
        pagingViewController.reloadMenu()
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
            width: self.view.bounds.width / CGFloat(self.pages.count),
            height: 40)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterReloadDataSource, userInfo: ["serverUrl": metadata.serverUrl])
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.pagingViewController.menuItemSize = .fixed(
                width: self.view.bounds.width / CGFloat(self.pages.count),
                height: 40)
            self.currentVC?.textField?.resignFirstResponder()
        }
    }

    // MARK: - NotificationCenter & Keyboard & TextField

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

    @objc func applicationDidEnterBackground(notification: Notification) {
        self.dismiss(animated: false, completion: nil)
    }
}

// MARK: - PagingViewController Delegate

extension NCSharePaging: PagingViewControllerDelegate {

    func pagingViewController(_ pagingViewController: PagingViewController, willScrollToItem pagingItem: PagingItem, startingViewController: UIViewController, destinationViewController: UIViewController) {

        currentVC?.textField?.resignFirstResponder()
        self.currentVC = destinationViewController as? NCSharePagingContent
    }
}

// MARK: - PagingViewController DataSource

extension NCSharePaging: PagingViewControllerDataSource {

    func pagingViewController(_: PagingViewController, viewControllerAt index: Int) -> UIViewController {

        let height = pagingViewController.options.menuHeight + NCSharePagingView.headerHeight + NCSharePagingView.tagHeaderHeight

        if pages[index] == .activity {
            guard let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as? NCActivity else {
                return UIViewController()
            }
            viewController.height = height
            viewController.showComments = true
            viewController.didSelectItemEnable = false
            viewController.metadata = metadata
            viewController.objectType = "files"
            return viewController
        } else if pages[index] == .sharing {
            guard let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as? NCShare else {
                return UIViewController()
            }
            viewController.metadata = metadata
            viewController.height = height
            return viewController
        } else {
            return applicationHandle.pagingViewController(pagingViewController, viewControllerAt: index, metadata: metadata, topHeight: height)
        }
    }

    func pagingViewController(_: PagingViewController, pagingItemAt index: Int) -> PagingItem {

        if pages[index] == .activity {
            return PagingIndexItem(index: index, title: NSLocalizedString("_activity_", comment: ""))
        } else if pages[index] == .sharing {
            return PagingIndexItem(index: index, title: NSLocalizedString("_sharing_", comment: ""))
        } else {
            return applicationHandle.pagingViewController(pagingViewController, pagingItemAt: index)
        }
    }

    func numberOfViewControllers(in pagingViewController: PagingViewController) -> Int {
        return self.pages.count
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
}

class NCSharePagingView: PagingView {

    static let headerHeight: CGFloat = 90
    static var tagHeaderHeight: CGFloat = 0
    var metadata = tableMetadata()

    public var headerHeightConstraint: NSLayoutConstraint?

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

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current

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
        headerView.info.text = CCUtility.transformedSize(metadata.size) + ", " + NSLocalizedString("_modified_", comment: "") + " " + dateFormatter.string(from: metadata.date as Date)
        headerView.info.textColor = .systemGray
        headerView.creation.text = NSLocalizedString("_creation_", comment: "") + " " + dateFormatter.string(from: metadata.creationDate as Date)
        headerView.creation.textColor = .systemGray
        headerView.upload.text = NSLocalizedString("_upload_", comment: "") + " " + dateFormatter.string(from: metadata.uploadDate as Date)
        headerView.upload.textColor = .systemGray

        headerView.details.setTitleColor(.label, for: .normal)
        headerView.details.setTitle(NSLocalizedString("_details_", comment: ""), for: .normal)
        headerView.details.layer.cornerRadius = 9
        headerView.details.layer.masksToBounds = true
        headerView.details.layer.backgroundColor = UIColor(red: 152.0 / 255.0, green: 167.0 / 255.0, blue: 181.0 / 255.0, alpha: 0.8).cgColor

        for tag in metadata.tags {
            headerView.tagListView.addTag(tag)
        }

        if metadata.tags.isEmpty {
            NCSharePagingView.tagHeaderHeight = 0
        } else {
            NCSharePagingView.tagHeaderHeight = headerView.tagListView.intrinsicContentSize.height + 10
        }

        addSubview(headerView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        pageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: options.menuHeight),
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),

            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: NCSharePagingView.headerHeight + NCSharePagingView.tagHeaderHeight),

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
    @IBOutlet weak var creation: UILabel!
    @IBOutlet weak var upload: UILabel!
    @IBOutlet weak var favorite: UIButton!
    @IBOutlet weak var details: UIButton!
    @IBOutlet weak var tagListView: TagListView!

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
                guard let metadata = NCManageDatabase.shared.getMetadataFromOcId(metadata.ocId) else { return }
                self.favorite.setImage(NCUtility.shared.loadImage(
                    named: "star.fill",
                    color: metadata.favorite ? NCBrandColor.shared.yellowFavorite : .systemGray,
                    size: 20), for: .normal)
            } else {
                NCContentPresenter.shared.showError(error: error)
            }
        }
    }

    @IBAction func touchUpInsideDetails(_ sender: UIButton) {

        creation.isHidden = !creation.isHidden
        upload.isHidden = !upload.isHidden
    }

    @objc func longTap(sender: UIGestureRecognizer) {
        UIPasteboard.general.string = path.text
        let error = NKError(errorCode: NCGlobal.shared.errorInternalError, errorDescription: "_copied_path_")
        NCContentPresenter.shared.showInfo(error: error)
    }
}
