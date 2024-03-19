//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//  Copyright © 2022 Henrik Storch. All rights reserved.
//
//  Author Henrik Storch <henrik.storch@nextcloud.com>
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

import Realm
import UIKit
import NextcloudKit

class NCTrash: UIViewController, NCTrashListCellDelegate, NCTrashGridCellDelegate, NCEmptyDataSetDelegate {

    @IBOutlet weak var collectionView: UICollectionView!

    var filePath = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkFileId: String?
    var emptyDataSet: NCEmptyDataSet?
    var dataSourceTask: URLSessionTask?
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
    var isEditMode = false
    var selectOcId: [String] = []
    var tabBarSelect: NCSelectableViewTabBar?
    var datasource: [tableTrash] = []
    var layoutForView: NCDBLayoutForView?
    var listLayout: NCListLayout!
    var gridLayout: NCGridLayout!
    var layoutKey = NCGlobal.shared.layoutViewTrash
    let refreshControl = UIRefreshControl()
    var filename: String?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarSelect = NCTrashSelectTabBar(tabBarController: tabBarController, delegate: self)

        view.backgroundColor = .systemBackground
        self.navigationController?.navigationBar.prefersLargeTitles = true

        // Cell
        collectionView.register(UINib(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCTrashGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        // Footer
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = .systemBackground

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)

        emptyDataSet = NCEmptyDataSet(view: collectionView, offset: NCGlobal.shared.heightButtonsView, delegate: self)
        setNavigationRightItems()

        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {

        appDelegate.activeViewController = self

        navigationController?.setNavigationBarAppearance()
        navigationItem.title = titleCurrentFolder

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "")
        gridLayout.itemForLine = CGFloat(layoutForView?.itemForLine ?? 3)

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }

        reloadDataSource()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadListingTrash()
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.setEditMode(false)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if let frame = tabBarController?.tabBar.frame {
            (tabBarSelect as? NCTrashSelectTabBar)?.hostingController?.view.frame = frame
        }
    }

    func setEditMode(_ editMode: Bool) {
        isEditMode = editMode
        selectOcId.removeAll()
        setNavigationRightItems(enableMenu: !editMode)
        collectionView.reloadData()
    }

    // MARK: - Empty

    func emptyDataSetView(_ view: NCEmptyView) {
        view.emptyImage.image = UIImage(named: "trash")?.image(color: .gray, size: UIScreen.main.bounds.width)
        view.emptyTitle.text = NSLocalizedString("_trash_no_trash_", comment: "")
        view.emptyDescription.text = NSLocalizedString("_trash_no_trash_description_", comment: "")
    }

    // MARK: TAP EVENT

    func tapRestoreListItem(with ocId: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            restoreItem(with: ocId)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    func tapMoreListItem(with objectId: String, image: UIImage?, sender: Any) {

        if !isEditMode {
            toggleMenuMore(with: objectId, image: image, isGridCell: false)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        } // else: undefined sender
    }

    func tapMoreGridItem(with objectId: String, namedButtonMore: String, image: UIImage?, indexPath: IndexPath, sender: Any) {

        if !isEditMode {
            toggleMenuMore(with: objectId, image: image, isGridCell: true)
        } else if let button = sender as? UIView {
            let buttonPosition = button.convert(CGPoint.zero, to: collectionView)
            let indexPath = collectionView.indexPathForItem(at: buttonPosition)
            collectionView(self.collectionView, didSelectItemAt: indexPath!)
        }
    }

    func longPressGridItem(with objectId: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    func longPressMoreGridItem(with objectId: String, namedButtonMore: String, gestureRecognizer: UILongPressGestureRecognizer) { }

    // MARK: - DataSource

    @objc func reloadDataSource(withQueryDB: Bool = true) {

        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "")
        datasource = NCManageDatabase.shared.getTrash(filePath: getFilePath(), sort: layoutForView?.sort, ascending: layoutForView?.ascending, account: appDelegate.account)
        collectionView.reloadData()
        setNavigationRightItems()

        guard let blinkFileId = blinkFileId else { return }
        for itemIx in 0..<self.datasource.count where self.datasource[itemIx].fileId.contains(blinkFileId) {
            let indexPath = IndexPath(item: itemIx, section: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIView.animate(withDuration: 0.3) {
                    self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
                } completion: { _ in
                    guard let cell = self.collectionView.cellForItem(at: indexPath) else { return }
                    cell.backgroundColor = .darkGray
                    UIView.animate(withDuration: 2) {
                        cell.backgroundColor = .clear
                        self.blinkFileId = nil
                    }
                }
            }
        }
    }

    func getFilePath() -> String {
        if filePath.isEmpty {
            guard let userId = (appDelegate.userId as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed) else { return "" }
            let filePath = appDelegate.urlBase + "/" + NextcloudKit.shared.nkCommonInstance.dav + "/trashbin/" + userId + "/trash"
            return filePath + "/"
        } else {
            return filePath + "/"
        }
    }
}
