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

class IndefiniteAnimatedView : UIView {
    
    private var activityIndicator : UIActivityIndicatorView?
    private var strokeThickness : CGFloat?
    private var strokeColor : UIColor?
    private var indefinteAnimatedLayer : CAShapeLayer?
    private var radius : CGFloat?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        if self.superview != nil {
            layoutAnimatedLayer()
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - Setter Functions
extension IndefiniteAnimatedView {
    
    func setIndefinite(radius: CGFloat) {
        if (self.radius != radius) {
            self.radius = radius
            
            self.getIndefinteAnimatedLayer().removeFromSuperlayer()
            self.indefinteAnimatedLayer = nil
            
            if superview != nil {
                layoutAnimatedLayer()
            }
        }
    }
    
    func setIndefinite(strokeThickness : CGFloat) {
        self.strokeThickness = strokeThickness
        if let strkthickness = self.strokeThickness {
            getIndefinteAnimatedLayer().lineWidth = strkthickness
        }
    }
    
    func setIndefinite(strokeColor: UIColor) {
        self.strokeColor = strokeColor
        getIndefinteAnimatedLayer().strokeColor = strokeColor.cgColor
    }
    
}

//MARK: - Getter Functions
extension IndefiniteAnimatedView {
    private func getIndefinteAnimatedLayer() -> CAShapeLayer {
        if self.indefinteAnimatedLayer != nil {
            return self.indefinteAnimatedLayer!
        } else {
            let localRingRadius : CGFloat = radius ?? 18
            let localStrokeThickness : CGFloat = strokeThickness ?? 2
            let localStrokeColor : UIColor = strokeColor ?? UIColor.black
            
            let arcCenter = CGPoint(x: localRingRadius + localStrokeThickness / 2 + 5, y: localRingRadius + localStrokeThickness / 2 + 5)
            let smoothedPath = UIBezierPath(arcCenter: arcCenter, radius: localRingRadius, startAngle: -CGFloat.pi / 2, endAngle: CGFloat.pi  + CGFloat.pi / 2, clockwise: true)
            
            indefinteAnimatedLayer = CAShapeLayer()
            indefinteAnimatedLayer?.contentsScale = UIScreen.main.scale
            indefinteAnimatedLayer?.frame = CGRect.init(x: 0, y: 0, width: arcCenter.x * 2, height: arcCenter.y * 2)
            indefinteAnimatedLayer?.fillColor = UIColor.clear.cgColor
            indefinteAnimatedLayer?.strokeColor = localStrokeColor.cgColor
            indefinteAnimatedLayer?.lineWidth = localStrokeThickness
            indefinteAnimatedLayer?.lineCap = CAShapeLayerLineCap.round
            indefinteAnimatedLayer?.lineJoin = CAShapeLayerLineJoin.bevel
            indefinteAnimatedLayer?.path = smoothedPath.cgPath
            
            let maskLayer = CALayer()
            let image = loadImageBundle(named: "angle-mask")!
            maskLayer.contents = image.cgImage
            maskLayer.frame = indefinteAnimatedLayer!.bounds
            indefinteAnimatedLayer?.mask = maskLayer
            
            let animationDuration  = TimeInterval.init(1)
            let linearCurve = CAMediaTimingFunction.init(name: .linear)
            let animation = CABasicAnimation.init(keyPath: "transform.rotation")
            animation.fromValue = 0
            animation.toValue = CGFloat.pi * 2
            animation.duration = animationDuration
            animation.timingFunction = linearCurve
            animation.isRemovedOnCompletion = false
            animation.repeatCount = .infinity
            animation.fillMode = .forwards
            animation.autoreverses = false
            indefinteAnimatedLayer?.mask?.add(animation, forKey: "rotate")
            
            
            let animationGroup = CAAnimationGroup.init()
            animationGroup.duration = animationDuration
            animationGroup.repeatCount = .infinity
            animationGroup.isRemovedOnCompletion = false
            animationGroup.timingFunction = linearCurve
            
            let strokeStartAnimation = CABasicAnimation.init(keyPath: "strokeStart")
            strokeStartAnimation.duration = animationDuration
            strokeStartAnimation.fromValue = 0.015
            strokeStartAnimation.toValue = 0.0001
            
            animationGroup.animations = [strokeStartAnimation]
            indefinteAnimatedLayer?.add(animationGroup, forKey: "progress")
        }
        return self.indefinteAnimatedLayer!
    }
}

//MARK: - ActivityIndicatorView Functions
extension IndefiniteAnimatedView {
    
    func removeAnimationLayer() {
        for view in self.subviews {
            if let activityView = view as? UIActivityIndicatorView {
                activityView.removeFromSuperview()
            }
        }
        getIndefinteAnimatedLayer().removeFromSuperlayer()
    }
    
    func startAnimation() {
        if let activityIndicator = activityIndicator {
            self.addSubview(activityIndicator)
            activityIndicator.frame = CGRect.init(x: 8, y: 8, width: self.frame.size.width - 16, height: self.frame.size.height - 16)
        }
    }
    
    func stopActivityIndicator() {
        activityIndicator?.stopAnimating()
    }
    
    func setActivityIndicator(color: UIColor) {
        activityIndicator = UIActivityIndicatorView.init(style: .whiteLarge)
        activityIndicator?.hidesWhenStopped = true
        activityIndicator?.startAnimating()
        activityIndicator?.color = color
    }
}
//MARK: -
extension IndefiniteAnimatedView {
    override func willMove(toSuperview newSuperview: UIView?) {
        if let _ = newSuperview {
            layoutAnimatedLayer()
        } else {
            getIndefinteAnimatedLayer().removeFromSuperlayer()
            indefinteAnimatedLayer = nil
        }
    }
    
    private func layoutAnimatedLayer() {
        let calayer = getIndefinteAnimatedLayer()
        self.layer.addSublayer(calayer)
        let widthDiff: CGFloat = bounds.width - layer.bounds.width
        let heightDiff: CGFloat = bounds.height - layer.bounds.height
        let xPos = bounds.width - layer.bounds.width / 2 - widthDiff / 2
        let yPos = bounds.height - layer.bounds.height / 2 - heightDiff / 2
        calayer.position = CGPoint.init(x: xPos, y: yPos)
    }
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let localRadius : CGFloat = radius ?? 18
        let localStrokeThickness : CGFloat = strokeThickness ?? 2
        for view in self.subviews {
            if let _ = view as? UIActivityIndicatorView {
                return CGSize.init(width: 50, height: 50)
            }
        }
        return CGSize.init(width: (localRadius + localStrokeThickness / 2 + 5) * 2, height: (localRadius + localStrokeThickness / 2 + 5) * 2)
    }
    
    private func loadImageBundle(named imageName:String) -> UIImage? {
        #if SWIFT_PACKAGE
            var imageBundle = Bundle.init(for: IHProgressHUD.self)
            if let resourcePath = Bundle.module.path(forResource: "IHProgressHUD", ofType: "bundle") {
                if let resourcesBundle = Bundle(path: resourcePath) {
                    imageBundle = resourcesBundle
                }
            }

            return UIImage(named: imageName, in: imageBundle, compatibleWith: nil)
        
        #else
            var imageBundle = Bundle.init(for: IHProgressHUD.self)
            if let resourcePath = imageBundle.path(forResource: "IHProgressHUD", ofType: "bundle") {
                if let resourcesBundle = Bundle(path: resourcePath) {
                    imageBundle = resourcesBundle
                }
            }

            return (UIImage(named: imageName, in: imageBundle, compatibleWith: nil))
        #endif
    }
}

