//
//  NCEmptyDataSet.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

@objc public protocol NCEmptyDataSetDelegate {
    @objc optional func emptyDataSetView(_ view: NCEmptyView)
}

class NCEmptyDataSet: NSObject {
    
    var emptyView: NCEmptyView?
    var delegate: NCEmptyDataSetDelegate?
    var timer: Timer?
    var numberItems: Int = 0
    
    init(view: UIView, offset: CGFloat = 0, delegate: NCEmptyDataSetDelegate?) {
        super.init()

        if let emptyView = UINib(nibName: "NCEmptyView", bundle: nil).instantiate(withOwner: self, options: nil).first as? NCEmptyView {
        
            self.delegate = delegate
            self.emptyView = emptyView
            
            emptyView.frame =  CGRect(x:0, y: 0, width:300, height:300)
            emptyView.isHidden = true
            emptyView.translatesAutoresizingMaskIntoConstraints = false

            emptyView.emptyTitle.sizeToFit()
            emptyView.emptyDescription.sizeToFit()
            
            view.addSubview(emptyView)

            let constantY: CGFloat = (view.frame.height - emptyView.frame.height) / 2 - offset
            
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
            emptyView.topAnchor.constraint(equalTo: view.topAnchor, constant: constantY).isActive = true
        }
    }
    
    func numberOfItemsInSection(_ numberItems: Int) {
        if let emptyView = emptyView {
            self.delegate?.emptyDataSetView?(emptyView)
            
            if !(timer?.isValid ?? false) && emptyView.isHidden == true {
                timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(timerHandler(_:)), userInfo: nil, repeats: false)
            }
            if numberItems > 0 {
                self.emptyView?.isHidden = true
            }
            
            self.numberItems = numberItems
        }
    }
    
    @objc func timerHandler(_ timer: Timer) {
        if numberItems == 0 {
            self.emptyView?.isHidden = false
        } else {
            self.emptyView?.isHidden = true
        }
    }
}

public class NCEmptyView: UIView {
    
    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTitle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!
}

