//
//  CloseButton.swift
//  WeScan
//
//  Created by Boris Emorine on 2/27/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit

/// A simple close button shaped like an "X".
final class CloseButton: UIControl {
    
    let xLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(xLayer)
        backgroundColor = .clear
        isAccessibilityElement = true
        accessibilityTraits = UIAccessibilityTraitButton
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        self.clipsToBounds = false
        xLayer.frame = rect
        xLayer.lineWidth = 3.0
        xLayer.path = pathForX(inRect: rect.insetBy(dx: xLayer.lineWidth / 2, dy: xLayer.lineWidth / 2)).cgPath
        xLayer.fillColor = UIColor.clear.cgColor
        xLayer.strokeColor = UIColor.black.cgColor
        xLayer.lineCap = kCALineCapRound
    }
    
    private func pathForX(inRect rect: CGRect) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: rect.origin)
        path.addLine(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y + rect.height))
        path.move(to: CGPoint(x: rect.origin.x + rect.width, y: rect.origin.y))
        path.addLine(to: CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height))
        
        return path
    }

}
