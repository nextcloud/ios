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
import TagListView

protocol NCSharePagingContent {
    var textField: UIView? { get }
}

class NCSharePaging: UIViewController {
    private let pagingViewController = NCShareHeaderViewController()
    private weak var appDelegate = UIApplication.shared.delegate as? AppDelegate
    private var currentVC: NCSharePagingContent?

    var metadata = tableMetadata()
    var controller: NCMainTabBarController?
    var pages: [NCBrandOptions.NCInfoPagingTab] = []
    var page: NCBrandOptions.NCInfoPagingTab = .activity

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = NSLocalizedString("_details_", comment: "")

        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""), style: .plain, target: self, action: #selector(exitTapped(_:)))

        let manageTagsAction = UIAction(title: NSLocalizedString("_edit_tags_", comment: ""), image: UIImage(systemName: "tag")) { [weak self] _ in
            self?.editTagsTapped(nil)
        }

        let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
        moreButton.menu = UIMenu(children: [manageTagsAction])
        navigationItem.rightBarButtonItem = moreButton

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)

        // *** MUST BE THE FIRST ONE ***
        pagingViewController.metadata = metadata
        pagingViewController.backgroundColor = .systemBackground
        pagingViewController.menuBackgroundColor = .systemBackground
        pagingViewController.selectedBackgroundColor = .systemBackground
        pagingViewController.indicatorColor = NCBrandColor.shared.getElement(account: metadata.account)
        pagingViewController.textColor = NCBrandColor.shared.textColor
        pagingViewController.selectedTextColor = NCBrandColor.shared.getElement(account: metadata.account)

        // Pagination
        addChild(pagingViewController)
        view.addSubview(pagingViewController.view)
        pagingViewController.didMove(toParent: self)

        // Customization
        pagingViewController.indicatorOptions = .visible(
            height: 1,
            zIndex: Int.max,
            spacing: .zero,
            insets: .zero
        )

        pagingViewController.borderOptions = .visible(height: 1, zIndex: Int.max, insets: .zero)

        // Contrain the paging view to all edges.
        pagingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pagingViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pagingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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

        pagingViewController.reloadMenu()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        currentVC = pagingViewController.pageViewController.selectedViewController as? NCSharePagingContent
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarAppearance()

        let capabilities = NCNetworking.shared.capabilities[metadata.account] ?? NKCapabilities.Capabilities()

        if !capabilities.fileSharingApiEnabled && !capabilities.filesComments && capabilities.activity.isEmpty {
            self.dismiss(animated: false, completion: nil)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        Task {
            await NCNetworking.shared.transferDispatcher.notifyAllDelegates { delegate in
                delegate.transferReloadDataSource(serverUrl: self.metadata.serverUrl, requestData: false, status: nil)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.currentVC?.textField?.resignFirstResponder()
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

    @objc func exitTapped(_ sender: Any?) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func editTagsTapped(_ sender: Any?) {
        guard let header = (pagingViewController.view as? NCSharePagingView)?.header else {
            return
        }

        header.presentTagEditor(from: self) { [weak self] tags in
            guard let self else { return }
            self.metadata.tags.removeAll()
            self.metadata.tags.append(objectsIn: tags, account: self.metadata.account)
            self.pagingViewController.metadata.tags.removeAll()
            self.pagingViewController.metadata.tags.append(objectsIn: tags, account: self.pagingViewController.metadata.account)
        }
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
        let height: CGFloat = 50

        if pages[index] == .activity {
            guard let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as? NCActivity else {
                return UIViewController()
            }
            viewController.height = height
            viewController.showComments = true
            viewController.didSelectItemEnable = false
            viewController.metadata = metadata
            viewController.objectType = "files"
            viewController.account = metadata.account
            return viewController
        } else if pages[index] == .sharing {
            guard let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as? NCShare else {
                return UIViewController()
            }
            viewController.metadata = metadata
            viewController.height = height
            viewController.controller = controller
            return viewController
        } else {
            return UIViewController()
        }
    }

    func pagingViewController(_: PagingViewController, pagingItemAt index: Int) -> PagingItem {

        if pages[index] == .activity {
            return PagingIndexItem(index: index, title: NSLocalizedString("_activity_", comment: ""))
        } else if pages[index] == .sharing {
            return PagingIndexItem(index: index, title: NSLocalizedString("_sharing_", comment: ""))
        } else {
            return PagingIndexItem(index: index, title: "")
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
    var metadata = tableMetadata()
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    public var headerHeightConstraint: NSLayoutConstraint?
    var header: NCShareHeader?

    // MARK: - View Life Cycle

    public init(options: Parchment.PagingOptions, collectionView: UICollectionView, pageView: UIView, metadata: tableMetadata) {
        super.init(options: options, collectionView: collectionView, pageView: pageView)

        self.metadata = metadata
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupConstraints() {
        guard let headerView = Bundle.main.loadNibNamed("NCShareHeader", owner: self, options: nil)?.first as? NCShareHeader else { return }
        header = headerView
        headerView.backgroundColor = .systemBackground

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        dateFormatter.locale = Locale.current

        headerView.setupUI(with: metadata)

        addSubview(headerView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        headerView.translatesAutoresizingMaskIntoConstraints = false
        pageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: options.menuHeight),
            collectionView.topAnchor.constraint(equalTo: headerView.bottomAnchor),

            headerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),

            pageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            pageView.topAnchor.constraint(equalTo: headerView.bottomAnchor)
        ])
    }
}
