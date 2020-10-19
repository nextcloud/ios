//
//  NCEmptyDataSet.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

class NCEmptyDataSet: NSObject {
    
    var emptyView: NCEmptyView?
    var collectionView: UICollectionView?
    
    init(collectionView: UICollectionView, image: UIImage?, title: String, description: String) {
        super.init()

        self.collectionView = collectionView
        
        if let emptyView = UINib(nibName: "NCEmptyView", bundle: nil).instantiate(withOwner: self, options: nil).first as? NCEmptyView {
        
            self.emptyView = emptyView
            
            emptyView.frame =  CGRect(x:0, y: 0, width:300, height:300)
            emptyView.isHidden = true
            emptyView.translatesAutoresizingMaskIntoConstraints = false

            emptyView.emptyImage.image = image
            emptyView.emptyTtle.text = NSLocalizedString(title, comment: "")
            emptyView.emptyDescription.text = NSLocalizedString(description, comment: "")
                       
            collectionView.addSubview(emptyView)

            let constantY: CGFloat = (collectionView.frame.height - emptyView.frame.height) / 2 - 100
            
            emptyView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor).isActive = true
            emptyView.topAnchor.constraint(equalTo: collectionView.topAnchor, constant: constantY).isActive = true
            
            //emptyView.layoutIfNeeded()
        }
    }
    
    func numberOfItemsInSection(_ numberItems: Int) {
        if numberItems == 0 {
            emptyView?.isHidden = false
        } else {
            emptyView?.isHidden = true
        }
    }
}

class NCEmptyView: UIView {
    
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTtle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!
}

