//
//  NCAvatar.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 16/11/2018.
//  Copyright © 2018 TWS. All rights reserved.
//

import Foundation

@IBDesignable class NCAvatar: UIImageView {
    
    @IBInspectable var roundness: CGFloat = 2 {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 5 {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var borderColor: UIColor = UIColor.blue {
        didSet{
            layoutSubviews()
        }
    }
    
    @IBInspectable var background: UIColor = UIColor.clear {
        didSet{
            layoutSubviews()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.cornerRadius = bounds.width / roundness
        layer.borderWidth = borderWidth
        layer.borderColor = borderColor.cgColor
        layer.backgroundColor = background.cgColor
        clipsToBounds = true
        
        let path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), cornerRadius: bounds.width / roundness)
        let mask = CAShapeLayer()
        
        mask.path = path.cgPath
        layer.mask = mask
    }
}
