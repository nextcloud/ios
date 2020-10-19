//
//  NCEmpty.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

class NCEmpty: NSObject {
    
    var emptyView: NCEmptyView?
    var collectioView: UICollectionView?
    
    init(collectioView: UICollectionView, image: UIImage?, title: String, description: String) {
        super.init()

        self.collectioView = collectioView
        if let emptyView = UINib(nibName: "NCEmptyView", bundle: nil).instantiate(withOwner: self, options: nil).first as? NCEmptyView {
        
            self.emptyView = emptyView
            
            emptyView.frame =  CGRect(x:0, y: 0, width:300, height:300)
            //emptyView.isHidden = true
            emptyView.translatesAutoresizingMaskIntoConstraints = false

            emptyView.emptyImage.image = image
            emptyView.emptyTtle.text = NSLocalizedString(title, comment: "")
            emptyView.emptyDescription.text = NSLocalizedString(description, comment: "")
                       
            collectioView.addSubview(emptyView)

            emptyView.centerXAnchor.constraint(equalTo: collectioView.centerXAnchor, constant: 0).isActive = true
            emptyView.topAnchor.constraint(equalTo: collectioView.topAnchor).isActive = true
            
            emptyView.layoutIfNeeded()
        }
    }
    
    func reload() {
        let items = collectioView?.numberOfItems(inSection: 0)
        if items == 0 {
            emptyView?.isHidden = false
        } else {
            //emptyView?.isHidden = true
        }
    }
}

class NCEmptyView: UIView {
    
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTtle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!
}

