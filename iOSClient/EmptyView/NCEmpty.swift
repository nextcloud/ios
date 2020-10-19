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
    
    init(collectioView: UICollectionView, image: UIImage, title: String, description: String) {
        super.init()

        self.collectioView = collectioView
        emptyView = UINib(nibName: "NCEmptyView", bundle: nil).instantiate(withOwner: self, options: nil).first as? NCEmptyView
            
        emptyView?.emptyImage.image = image
        emptyView?.emptyTtle.text = title
        emptyView?.emptyDescription.text = description
                        
        emptyView?.leftAnchor.constraint(equalTo: collectioView.leftAnchor).isActive = true
        emptyView?.rightAnchor.constraint(equalTo: collectioView.rightAnchor).isActive = true
        emptyView?.topAnchor.constraint(equalTo: collectioView.topAnchor).isActive = true
        emptyView?.bottomAnchor.constraint(equalTo: collectioView.bottomAnchor).isActive = true
    }
    
    func reload() {
        let items = collectioView?.numberOfItems(inSection: 0)
        if items == 0 && emptyView != nil {
            collectioView?.addSubview(emptyView!)
        } else {
            emptyView!.removeFromSuperview()
        }
    }
}

class NCEmptyView: UIView {
    
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTtle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!
}

