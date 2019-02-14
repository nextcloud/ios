//
//  ResizeControl.swift
//  CropViewController
//
//  Created by Guilherme Moura on 2/26/16.
//  Copyright © 2016 Reefactor, Inc. All rights reserved.
// Credit https://github.com/sprint84/PhotoCropEditor

import UIKit

protocol ResizeControlDelegate: class {
    func resizeControlDidBeginResizing(_ control: ResizeControl)
    func resizeControlDidResize(_ control: ResizeControl)
    func resizeControlDidEndResizing(_ control: ResizeControl)
}

class ResizeControl: UIView {
    weak var delegate: ResizeControlDelegate?
    var translation = CGPoint.zero
    var enabled = true
    fileprivate var startPoint = CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: CGRect(x: frame.origin.x, y: frame.origin.y, width: 44.0, height: 44.0))
        initialize()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(frame: CGRect(x: 0, y: 0, width: 44.0, height: 44.0))
        initialize()
    }
    
    fileprivate func initialize() {
        backgroundColor = UIColor.clear
        isExclusiveTouch = true
        
        let gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(ResizeControl.handlePan(_:)))
        addGestureRecognizer(gestureRecognizer)
    }
    
    @objc func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
        if !enabled {
            return
        }
        
        switch gestureRecognizer.state {
        case .began:
            let translation = gestureRecognizer.translation(in: superview)
            startPoint = CGPoint(x: round(translation.x), y: round(translation.y))
            delegate?.resizeControlDidBeginResizing(self)
        case .changed:
            let translation = gestureRecognizer.translation(in: superview)
            self.translation = CGPoint(x: round(startPoint.x + translation.x), y: round(startPoint.y + translation.y))
            delegate?.resizeControlDidResize(self)
        case .ended, .cancelled:
            delegate?.resizeControlDidEndResizing(self)
        default: ()
        }
        
    }
}
