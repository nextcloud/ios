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

import UIKit
import NextcloudKit
import RealmSwift

class NCTrash: UIViewController, NCTrashListCellDelegate, NCTrashGridCellDelegate {

	@IBOutlet weak var vHeader: FileActionsHeader!
	@IBOutlet weak var collectionView: UICollectionView!

    var filePath = ""
    var titleCurrentFolder = NSLocalizedString("_trash_view_", comment: "")
    var blinkFileId: String?
    var dataSourceTask: URLSessionTask?
    let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    let utilityFileSystem = NCUtilityFileSystem()
    let utility = NCUtility()
	var isEditMode = false {
		didSet {
			vHeader.setIsEditingMode(isEditingMode: isEditMode)
		}
	}
    var selectOcId: [String] = []
    var selectionToolbar: NCTrashSelectToolBar!
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
        selectionToolbar = NCTrashSelectToolBar(containerView: view, placeholderFrame: selectToolBarFrame, delegate: self)

        view.backgroundColor = NCBrandColor.shared.appBackgroundColor
        self.navigationController?.navigationBar.prefersLargeTitles = true

        collectionView.register(UINib(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "listCell")
        collectionView.register(UINib(nibName: "NCTrashGridCell", bundle: nil), forCellWithReuseIdentifier: "gridCell")

        collectionView.register(UINib(nibName: "NCSectionFirstHeaderEmptyData", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "sectionFirstHeaderEmptyData")
        collectionView.register(UINib(nibName: "NCSectionFooter", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "sectionFooter")

        collectionView.alwaysBounceVertical = true
        collectionView.backgroundColor = NCBrandColor.shared.appBackgroundColor

        listLayout = NCListLayout()
        gridLayout = NCGridLayout()

        // Add Refresh Control
        collectionView.refreshControl = refreshControl
        refreshControl.tintColor = NCBrandColor.shared.textColor2
        refreshControl.addTarget(self, action: #selector(loadListingTrash), for: .valueChanged)

		updateHeadersView()
		
        NotificationCenter.default.addObserver(self, selector: #selector(reloadDataSource), name: NSNotification.Name(rawValue: NCGlobal.shared.notificationCenterReloadDataSource), object: nil)
    }

	private func updateHeadersView() {
		vHeader?.setIsEditingMode(isEditingMode: isEditMode)
		vHeader?.setViewModeMenu(viewMenuElements: createViewModeMenuActions(), image: viewModeImage?.templateRendered())
		
		vHeader?.onSelectModeChange = { [weak self] isSelectionMode in
			self?.setEditMode(isSelectionMode)
			self?.updateHeadersView()
			self?.vHeader?.setSelectionState(selectionState: .none)
		}
		
		vHeader?.onSelectAll = { [weak self] in
			guard let self = self else { return }
			self.selectAll()
			let selectionState: FileActionsHeaderSelectionState = self.selectOcId.count == 0 ? .none : .all
			self.vHeader?.setSelectionState(selectionState: selectionState)
		}
		updateSelectionToolbar()
	}
	
	private var selectToolBarFrame: CGRect {
		let toolbarHeight = AppScreenConstants.toolbarHeight
		return CGRect(x: 0, y: view.bounds.size.height - toolbarHeight, width: view.bounds.size.width, height: toolbarHeight)
	}
	
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarAppearance()
        navigationItem.title = titleCurrentFolder
        layoutForView = NCManageDatabase.shared.getLayoutForView(account: appDelegate.account, key: NCGlobal.shared.layoutViewTrash, serverUrl: "")

        if layoutForView?.layout == NCGlobal.shared.layoutList {
            collectionView.collectionViewLayout = listLayout
        } else {
            collectionView.collectionViewLayout = gridLayout
        }

        isEditMode = false
        setNavigationLeftItems()
		updateHeadersView()
		
        reloadDataSource()
        loadListingTrash()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Cancel Queue & Retrieves Properties
        NCNetworking.shared.downloadThumbnailTrashQueue.cancelAll()
        dataSourceTask?.cancel()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
		selectionToolbar.hostingController?.view.frame = selectToolBarFrame
    }

    // MARK: - Layout

    func updateSelectionToolbar() {
        if isEditMode {
            selectionToolbar.update(selectOcId: selectOcId)
            selectionToolbar.show()
        } else if navigationItem.rightBarButtonItems == nil || (!isEditMode && !selectionToolbar.isHidden()) {
            selectionToolbar.hide()
        }
    }
    
    func setNavigationLeftItems() {
        if layoutKey == NCGlobal.shared.layoutViewTrash {
            navigationItem.leftItemsSupplementBackButton = true
            if navigationController?.viewControllers.count == 1 {
                navigationItem.setLeftBarButtonItems([UIBarButtonItem(title: NSLocalizedString("_close_", comment: ""),
                                                                      style: .plain,
                                                                      action: { [weak self] in
                    self?.dismiss(animated: true)
                })], animated: true)
            }
        }
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

        datasource = NCManageDatabase.shared.getTrash(filePath: getFilePath(), account: appDelegate.account)
        collectionView.reloadData()
        updateHeadersView()

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


extension NCTrash {
	private var viewModeImage: UIImage? {
		let imageName = collectionView.collectionViewLayout == listLayout ? "FileSelection/view_mode_list" : "FileSelection/view_mode_grid"
		return UIImage(named: imageName)
	}
	
	func createViewModeMenuActions() -> [UIMenuElement] {
		let layoutForView = collectionView.collectionViewLayout

		let listImage = UIImage(named: "FileSelection/view_mode_list")?.templateRendered()
		let gridImage = UIImage(named: "FileSelection/view_mode_grid")?.templateRendered()

		let list = UIAction(title: NSLocalizedString("_list_", comment: ""), image: listImage, state: layoutForView == listLayout ? .on : .off) { [weak self] _ in
			self?.onListSelected()
			self?.updateHeadersView()
		}

		let grid = UIAction(title: NSLocalizedString("_icons_", comment: ""), image: gridImage, state: layoutForView == gridLayout ? .on : .off) { [weak self] _ in
			self?.onGridSelected()
			self?.updateHeadersView()
		}
		return [list, grid]
	}
}
