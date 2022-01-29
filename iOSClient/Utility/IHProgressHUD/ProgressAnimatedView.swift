//
//  Converted to Swift 4 by Swiftify v4.2.29618 - https://objectivec2swift.com/
//
//  IndefiniteAnimatedView.swift
//  SVProgressHUD, https://github.com/SVProgressHUD/SVProgressHUD
//
//  Original Copyright (c) 2014-2018 Guillaume Campagna. All rights reserved.
//  Modified Copyright © 2018 Ibrahim Hassan. All rights reserved.
//

import UIKit

class ProgressAnimatedView: UIView {
    
    private var radius : CGFloat?
    private var strokeThickness : CGFloat?
    private var strokeColor : UIColor?
    private var strokeEnd : CGFloat?
    private var ringAnimatedLayer : CAShapeLayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func willMove(toSuperview newSuperview: UIView?) {
        if let _ = newSuperview {
            layoutAnimatedLayer()
        } else {
            getRingAnimatedLayer().removeFromSuperlayer()
            ringAnimatedLayer = nil
        }
    }
    
    func layoutAnimatedLayer() {
        let rlayer = getRingAnimatedLayer()
        layer.addSublayer(rlayer)
        let widthDiff = bounds.width - layer.bounds.width
        let heightDiff = bounds.height - layer.bounds.height
        let layerPositionX = bounds.width  - layer.bounds.width / 2 - widthDiff / 2
        let layerPositionY = bounds.height - layer.bounds.height / 2 - heightDiff / 2
        rlayer.position = CGPoint.init(x: layerPositionX, y: layerPositionY)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let localRadius : CGFloat = radius ?? 18
        let localStrokeThickness : CGFloat = strokeThickness ?? 2
        return CGSize(width: (localRadius + localStrokeThickness / 2 + 5) * 2, height: (localRadius + localStrokeThickness / 2 + 5) * 2)
    }

}

//MARK: - Setter
extension ProgressAnimatedView {
    @objc public func set(radius: CGFloat) {
        if radius != self.radius {
            self.radius = radius
            
            getRingAnimatedLayer().removeFromSuperlayer()
            ringAnimatedLayer = nil
            
            if superview != nil {
                layoutAnimatedLayer()
            }
        }
    }
    
    func set(strokeThickness : CGFloat) {
        self.strokeThickness = strokeThickness
        getRingAnimatedLayer().lineWidth = strokeThickness

        if superview != nil {
            layoutAnimatedLayer()
        }
        
    }
    
    func set(strokeEnd: CGFloat) {
        self.strokeEnd = strokeEnd
        getRingAnimatedLayer().strokeEnd = strokeEnd
        
        if superview != nil {
            layoutAnimatedLayer()
        }
        
    }
    
    func set(strokeColor: UIColor) {
        
        self.strokeColor = strokeColor
        self.getRingAnimatedLayer().strokeColor = strokeColor.cgColor
        
        if superview != nil {
            layoutAnimatedLayer()
        }
    }
}

//MARK: - Getter
extension ProgressAnimatedView {
    private func getRingAnimatedLayer() -> CAShapeLayer {
        if self.ringAnimatedLayer != nil {
            return self.ringAnimatedLayer!
        } else {
            let localStrokeThickness: CGFloat = strokeThickness ?? 2
            let localRingRadius: CGFloat = radius ?? 18
            
            let arcCenter = CGPoint(x: localRingRadius + localStrokeThickness / 2 + 5, y: localRingRadius + localStrokeThickness / 2 + 5)
            let smoothedPath = UIBezierPath(arcCenter: arcCenter, radius: localRingRadius, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi  + CGFloat.pi / 2, clockwise: true)
            
            let _ringAnimatedLayer = CAShapeLayer()
            _ringAnimatedLayer.contentsScale = UIScreen.main.scale
            _ringAnimatedLayer.frame = CGRect(x: 0.0, y: 0.0, width: arcCenter.x * 2, height: arcCenter.y * 2)
            _ringAnimatedLayer.fillColor = UIColor.clear.cgColor
            _ringAnimatedLayer.strokeColor = strokeColor?.cgColor
            _ringAnimatedLayer.lineWidth = localStrokeThickness
            _ringAnimatedLayer.lineCap = .round
            _ringAnimatedLayer.lineJoin = .bevel
            _ringAnimatedLayer.path = smoothedPath.cgPath
            self.ringAnimatedLayer = _ringAnimatedLayer
        }
        return self.ringAnimatedLayer!
    }
    
}
