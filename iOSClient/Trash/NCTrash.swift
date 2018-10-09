//
//  NCTrash.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 02/10/2018.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//

import Foundation
 

class NCTrash: UIViewController , UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate, NCTrashListDelegate {
    
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    var path = ""
    var itemHeight: CGFloat = 60
    var datasource = [tableTrash]()

    var gridLayout: ListLayout!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.register(UINib.init(nibName: "NCTrashListCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        collectionView.collectionViewLayout = ListLayout(itemHeight: 60)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if path == "" {
            let userID = (appDelegate.activeUserID as NSString).addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlFragmentAllowed)
            path = k_dav + "/trashbin/" + userID! + "/trash/"
        }
        
        let ocNetworking = OCnetworking.init(delegate: self, metadataNet: nil, withUser: appDelegate.activeUser, withUserID: appDelegate.activeUserID, withPassword: appDelegate.activePassword, withUrl: appDelegate.activeUrl)
        
        ocNetworking?.listingTrash(appDelegate.activeUrl, path:path, account: appDelegate.activeAccount, success: { (item) in
            
            NCManageDatabase.sharedInstance.deleteTrash(filePath: self.path)
            self.datasource = NCManageDatabase.sharedInstance.addTrashs(item as! [tableTrash])!
            
            self.collectionView.reloadData()
            
        }, failure: { (message, errorCode) in
            
            print("error " + message!)
        })
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: nil) { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    // MARK: tap cell
    func tapRestoreDelegate(with fileID: String) {
        
    }
    
    func tapMoreDelegate(with fileID: String) {
        
    }
    
    // MARK: collectionView methods
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return datasource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! NCTrashListCell
        cell.delegate = self

        let tableTrash = datasource[indexPath.item]
        
        if tableTrash.directory {
            cell.configure(with: tableTrash.fileID ,image: CCGraphics.changeThemingColorImage(UIImage.init(named: "folder"), multiplier: 3, color: NCBrandColor.sharedInstance.brandElement), title: tableTrash.trashbinFileName, info: CCUtility.dateDiff(tableTrash.date as Date))
        } else {
            
            var image: UIImage?
            if tableTrash.iconName.count > 0 {
                image = UIImage.init(named: tableTrash.iconName)
            } else {
                image = UIImage.init(named: "file")
            }
            
            cell.configure(with: tableTrash.fileID, image: image, title: tableTrash.trashbinFileName, info: CCUtility.dateDiff(tableTrash.date as Date) + " " + CCUtility.transformedSize(tableTrash.size))
        }
                
        return cell
    }
}

class ListLayout: UICollectionViewFlowLayout {
    
    var itemHeight: CGFloat = 60
    
    init(itemHeight: CGFloat) {
        super.init()
        
        minimumLineSpacing = 1
        minimumInteritemSpacing = 1
        
        self.itemHeight = itemHeight
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var itemSize: CGSize {
        get {
            if let collectionView = collectionView {
                let itemWidth: CGFloat = collectionView.frame.width
                return CGSize(width: itemWidth, height: self.itemHeight)
            }
            
            // Default fallback
            return CGSize(width: 100, height: 100)
        }
        set {
            super.itemSize = newValue
        }
    }
    
    override func targetContentOffset(forProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return proposedContentOffset
    }
    
}
