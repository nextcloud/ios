//
//  NCShare.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 17/07/2019.
//  Copyright © 2019 Marino Faggiana. All rights reserved.
//
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

import Foundation
import Parchment

class NCShare: UIViewController {
    
    private let pagingViewController = NCShareHeaderViewController()
    
    @objc var metadata: tableMetadata?
    @objc var shareLink: String = ""
    @objc var shareUserAndGroup: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        
        pagingViewController.metadata = metadata
        
        // Navigation Controller
        var image = CCGraphics.changeThemingColorImage(UIImage(named: "exit")!, width: 40, height: 40, color: UIColor.gray)
        image = image?.withRenderingMode(.alwaysOriginal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style:.plain, target: self, action: #selector(exitTapped))

        // Pagination
        addChild(pagingViewController)
        view.addSubview(pagingViewController.view)
        pagingViewController.didMove(toParent: self)
        
        pagingViewController.selectedTextColor = .black
        pagingViewController.indicatorColor = .black
        pagingViewController.indicatorOptions = .visible(
            height: 1,
            zIndex: Int.max,
            spacing: .zero,
            insets: .zero
        )
        
        // Contrain the paging view to all edges.
        pagingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pagingViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pagingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            pagingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pagingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        // Set our data source and delegate.
        pagingViewController.dataSource = self
    }
    
    @objc func exitTapped() {
        self.dismiss(animated: true, completion: nil)
    }
}

extension NCShare: PagingViewControllerDataSource {
    
    func pagingViewController<T>(_ pagingViewController: PagingViewController<T>, viewControllerForIndex index: Int) -> UIViewController {
        
        var viewController: UIViewController?
        let storyboard = UIStoryboard(name: "NCShare", bundle: nil)

        switch index {
        case 0:
            viewController = storyboard.instantiateViewController(withIdentifier: "activity")
        case 1:
            viewController = storyboard.instantiateViewController(withIdentifier: "comments")
        case 2:
            viewController = storyboard.instantiateViewController(withIdentifier: "sharing")
        default:
           print("")
        }

        return viewController!
    }
    
    func pagingViewController<T>(_ pagingViewController: PagingViewController<T>, pagingItemForIndex index: Int) -> T {
        switch index {
        case 0:
            return PagingIndexItem(index: index, title: "activity") as! T
        case 1:
            return PagingIndexItem(index: index, title: "comments") as! T
        case 2:
            return PagingIndexItem(index: index, title: "sharing") as! T
        default:
            return PagingIndexItem(index: index, title: "") as! T
        }
    }
    
    func numberOfViewControllers<T>(in: PagingViewController<T>) -> Int{
        return 3
    }
}

class NCShareHeaderViewController: PagingViewController<PagingIndexItem> {
    
    public var image: UIImage?
    public var metadata: tableMetadata?

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
    
    static let HeaderHeight: CGFloat = 200
    var metadata: tableMetadata?
    
    var headerHeightConstraint: NSLayoutConstraint?
    
    public init(options: Parchment.PagingOptions, collectionView: UICollectionView, pageView: UIView, metadata: tableMetadata?) {
        super.init(options: options, collectionView: collectionView, pageView: pageView)
        
        self.metadata = metadata
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setupConstraints() {
        
        let headerView = Bundle.main.loadNibNamed("NCShareHeaderView", owner: self, options: nil)?.first as! NCShareHeaderView
        
        if FileManager.default.fileExists(atPath: CCUtility.getDirectoryProviderStorageIconFileID(metadata!.fileID, fileNameView: metadata!.fileNameView)) {
            headerView.imageView.image = UIImage.init(contentsOfFile: CCUtility.getDirectoryProviderStorageIconFileID(metadata!.fileID, fileNameView: metadata!.fileNameView))
        } else {
            if metadata!.iconName.count > 0 {
                headerView.imageView.image = UIImage.init(named: metadata!.iconName)
            } else if metadata!.directory {
                let image = UIImage.init(named: "folder")!
                headerView.imageView.image = CCGraphics.changeThemingColorImage(image, width: image.size.width*2, height: image.size.height*2, color: NCBrandColor.sharedInstance.brandElement)
            } else {
                headerView.imageView.image = UIImage.init(named: "file")
            }
        }
        headerView.fileName.text = metadata?.fileNameView
        if metadata!.favorite {
            headerView.favorite.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 40, height: 40, color: NCBrandColor.sharedInstance.yellowFavorite), for: .normal)
        } else {
            headerView.favorite.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "favorite"), width: 40, height: 40, color: NCBrandColor.sharedInstance.textInfo), for: .normal)
        }
        headerView.info.text = CCUtility.transformedSize(metadata!.size) + ", " + CCUtility.dateDiff(metadata!.date as Date)
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
            pageView.topAnchor.constraint(equalTo: topAnchor)
        ])
    }
}

class NCShareHeaderView: UIView {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var fileName: UILabel!
    @IBOutlet weak var info: UILabel!
    @IBOutlet weak var favorite: UIButton!
}
