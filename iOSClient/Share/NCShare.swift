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

class NCSharePaging: UIViewController {
    
    private let pagingViewController = NCShareHeaderViewController()
    
    @objc var metadata: tableMetadata?

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

extension NCSharePaging: PagingViewControllerDataSource {
    
    func pagingViewController<T>(_ pagingViewController: PagingViewController<T>, viewControllerForIndex index: Int) -> UIViewController {
        
        let height = pagingViewController.options.menuHeight + NCSharePagingView.HeaderHeight
        
        switch index {
        case 0:
            let viewController = UIStoryboard(name: "NCActivity", bundle: nil).instantiateInitialViewController() as! NCActivity
            viewController.insets = UIEdgeInsets(top: height, left: 0, bottom: 0, right: 0)
            viewController.refreshControlEnable = false
            viewController.didSelectItemEnable = false
            viewController.filterFileID = metadata!.fileID
            return viewController
        case 1:
            let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "comments") as! NCShareComments
            viewController.metadata = metadata!
            return viewController
        case 2:
            let viewController = UIStoryboard(name: "NCShare", bundle: nil).instantiateViewController(withIdentifier: "sharing") as! NCShare
            viewController.metadata = metadata!
            viewController.height = height
            return viewController
        default:
            return UIViewController()
        }
    }
    
    func pagingViewController<T>(_ pagingViewController: PagingViewController<T>, pagingItemForIndex index: Int) -> T {
        switch index {
        case 0:
            return PagingIndexItem(index: index, title: NSLocalizedString("_activity_", comment: "")) as! T
        case 1:
            return PagingIndexItem(index: index, title: NSLocalizedString("_comments_", comment: "")) as! T
        case 2:
            return PagingIndexItem(index: index, title: NSLocalizedString("_sharing_", comment: "")) as! T
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

// MARK: - Comments

class NCShareComments: UIViewController {
    
    var metadata: tableMetadata?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    override func viewDidLoad() {
        super.viewDidLoad()
        
        OCNetworking.sharedManager()?.getCommentsWithAccount(appDelegate.activeAccount, fileID: metadata?.fileID, completion: { (account, list, message, errorCode) in
            print("ciao")
        })
    }
}

// MARK: - Share

class NCShare: UIViewController, UIGestureRecognizerDelegate, NCShareLinkCellDelegate {
    
    var metadata: tableMetadata?
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    public var height: CGFloat = 0
    
    private var viewMenuShareLink: UIView?
    private var shareLinkMenuView: NCShareLinkMenuView?
    private var sharesTable: [tableShare]?

    @IBOutlet weak var viewContainerConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchField: UITextField!
    @IBOutlet weak var returnSearchButton: UIButton!
    @IBOutlet weak var shareLinkImage: UIImageView!
    @IBOutlet weak var shareLinkLabel: UILabel!
    @IBOutlet weak var addShareLinkButton: UIButton!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewContainerConstraint.constant = height
        
        searchField.placeholder = NSLocalizedString("_shareLinksearch_placeholder_", comment: "")
        
        returnSearchButton.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "arrowRight"), width: 40, height: 40, color: UIColor.gray), for: .normal)
        shareLinkLabel.text = NSLocalizedString("_share_link_", comment: "")
        addShareLinkButton.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "add"), width: 40, height: 40, color: UIColor.gray), for: .normal)
        shareLinkImage.image = NCShareUtility.sharedInstance.createLinkAvatar()
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        
        tableView.register(UINib.init(nibName: "NCShareLinkCell", bundle: nil), forCellReuseIdentifier: "cellLink")
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        viewMenuShareLink?.removeFromSuperview()
    }
    
    func tapCopy(with idRemoteShared: Int, sender: Any) {
        
    }
    
    func tapMenu(with idRemoteShared: Int, sender: Any) {
        
    }
}

extension NCShare: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

extension NCShare: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numOfRows = 0
        let shares = NCManageDatabase.sharedInstance.getTableSharesV2(metadata: metadata!)
        
        if shares.share != nil {
            numOfRows = shares.share!.count
        }
        
        return numOfRows
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let shares = NCManageDatabase.sharedInstance.getTableSharesV2(metadata: metadata!)
        let tableShare = shares.share![indexPath.row]
        
        if tableShare.shareLink != "" {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "cellLink", for: indexPath) as? NCShareLinkCell {
                cell.idRemoteShared = tableShare.idRemoteShared
                cell.delegate = self
                return cell
            }
        }
        
        return UITableViewCell()
    }
}

class NCShareLinkCell: UITableViewCell {
    
    private let iconShare: CGFloat = 200
    
    var idRemoteShared: Int = 0
    var delegate: NCShareLinkCellDelegate?

    @IBOutlet weak var imageItem: UIImageView!
    @IBOutlet weak var labelTitle: UILabel!
    @IBOutlet weak var buttonCopy: UIButton!
    @IBOutlet weak var buttonMenu: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imageItem.image = NCShareUtility.sharedInstance.createLinkAvatar()
        labelTitle.text = NSLocalizedString("_share_link_", comment: "")
        buttonCopy.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareCopy"), width:100, height: 100, color: UIColor.gray), for: .normal)
        buttonMenu.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "shareMenu"), width:100, height: 100, color: UIColor.gray), for: .normal)
    }
    
    @IBAction func touchUpInsideCopy(_ sender: Any) {
        delegate?.tapCopy(with: idRemoteShared, sender: sender)
    }
    
    @IBAction func touchUpInsideMenu(_ sender: Any) {
        delegate?.tapMenu(with: idRemoteShared, sender: sender)
    }
}

protocol NCShareLinkCellDelegate {
    func tapCopy(with idRemoteShared: Int, sender: Any)
    func tapMenu(with idRemoteShared: Int, sender: Any)
}

// MARK: - AddShareLink

extension NCShare {
    
    @IBAction func touchUpInsideAddShareLink(_ sender: Any) {
        
        let globalPoint = self.view!.superview?.convert(self.view.frame.origin, to: nil)

        let window = UIApplication.shared.keyWindow!
        viewMenuShareLink = UIView(frame: window.bounds)
        window.addSubview(viewMenuShareLink!)
        
        let shareLinkMenuView = Bundle.main.loadNibNamed("NCShareLinkMenuView", owner: self, options: nil)?.first as? NCShareLinkMenuView
        let shareLinkMenuViewX = self.view.bounds.width - (shareLinkMenuView?.frame.width)! - 40 + globalPoint!.x
        var shareLinkMenuViewY = height + 10 + globalPoint!.y
        if (self.view.bounds.height - (height + 10))  < shareLinkMenuView!.height {
            shareLinkMenuViewY = shareLinkMenuViewY - height
        }
        shareLinkMenuView?.frame = CGRect(x: shareLinkMenuViewX, y: shareLinkMenuViewY, width: shareLinkMenuView!.width, height: shareLinkMenuView!.height)
        viewMenuShareLink?.addSubview(shareLinkMenuView!)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandler))
        tap.delegate = self
        viewMenuShareLink?.addGestureRecognizer(tap)
    }
    
    @objc func tapHandler(gesture: UITapGestureRecognizer) {
        viewMenuShareLink?.removeFromSuperview()
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return gestureRecognizer.view == touch.view
    }
}

// MARK: - hareLinkMenuView

class NCShareLinkMenuView: UIView {
    
    @IBOutlet weak var switchAllowEditing: UISwitch!
    @IBOutlet weak var labelAllowEditing: UILabel!
    
    @IBOutlet weak var switchHideDownload: UISwitch!
    @IBOutlet weak var labelHideDownload: UILabel!
    
    @IBOutlet weak var switchPasswordProtect: UISwitch!
    @IBOutlet weak var labelPasswordProtect: UILabel!
    @IBOutlet weak var fieldPasswordProtect: UITextField!
    
    @IBOutlet weak var switchSetExpirationDate: UISwitch!
    @IBOutlet weak var labelSetExpirationDate: UILabel!
    @IBOutlet weak var fieldSetExpirationDate: UITextField!
    
    @IBOutlet weak var imageNoteToRecipient: UIImageView!
    @IBOutlet weak var labelNoteToRecipient: UILabel!
    @IBOutlet weak var textViewNoteToRecipient: UITextView!
    
    @IBOutlet weak var buttonDeleteShareLink: UIButton!
    @IBOutlet weak var labelDeleteShareLink: UILabel!
    
    @IBOutlet weak var buttonAddAnotherLink: UIButton!
    @IBOutlet weak var labelAddAnotherLink: UILabel!
    
    public let width: CGFloat = 250
    public let height: CGFloat = 470
    public var idRemoteShared: Int = 0
    
    override func awakeFromNib() {
        
        self.frame.size.width = width
        self.frame.size.height = height

        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 5
        layer.masksToBounds = false
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowOpacity = 0.2
        layer.cornerRadius = 5
        
        switchAllowEditing.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchHideDownload.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchPasswordProtect.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        switchSetExpirationDate.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        
        imageNoteToRecipient.image = CCGraphics.changeThemingColorImage(UIImage.init(named: "file_txt"), width: 100, height: 100, color: UIColor.black)
        buttonDeleteShareLink.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "trash"), width: 100, height: 100, color: UIColor.black), for: .normal)
        buttonAddAnotherLink.setImage(CCGraphics.changeThemingColorImage(UIImage.init(named: "add"), width: 100, height: 100, color: UIColor.black), for: .normal)
    }
}

class NCShareUtility: NSObject {
    @objc static let sharedInstance: NCShareUtility = {
        let instance = NCShareUtility()
        return instance
    }()
    
    func createLinkAvatar() -> UIImage? {
        
        let size: CGFloat = 200
        
        let bottomImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "circle"), width: size, height: size, color: NCBrandColor.sharedInstance.brand)
        let topImage = CCGraphics.changeThemingColorImage(UIImage.init(named: "sharebylink"), width: size, height: size, color: UIColor.white)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0.0)
        bottomImage?.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: size, height: size)))
        topImage?.draw(in: CGRect(origin:  CGPoint(x: size/4, y: size/4), size: CGSize(width: size/2, height: size/2)))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

