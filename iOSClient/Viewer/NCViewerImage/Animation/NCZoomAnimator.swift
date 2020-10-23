
import UIKit

protocol ZoomAnimatorDelegate: class {
    func transitionWillStartWith(zoomAnimator: ZoomAnimator)
    func transitionDidEndWith(zoomAnimator: ZoomAnimator)
    func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView?
    func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect?
}

class ZoomAnimator: NSObject {
    
    weak var fromDelegate: ZoomAnimatorDelegate?
    weak var toDelegate: ZoomAnimatorDelegate?

    var transitionImageView: UIImageView?
    var isPresenting: Bool = true
    
    fileprivate func animateZoomInTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let containerView = transitionContext.containerView
        
        guard let toVC = transitionContext.viewController(forKey: .to),
            let fromVC = transitionContext.viewController(forKey: .from),
            let fromReferenceImageView = self.fromDelegate?.referenceImageView(for: self),
            let toReferenceImageView = self.toDelegate?.referenceImageView(for: self),
            let fromReferenceImageViewFrame = self.fromDelegate?.referenceImageViewFrameInTransitioningView(for: self)
            else {
                return
        }
        
        self.fromDelegate?.transitionWillStartWith(zoomAnimator: self)
        self.toDelegate?.transitionWillStartWith(zoomAnimator: self)
        
        toVC.view.alpha = 0
        toReferenceImageView.isHidden = true
        containerView.addSubview(toVC.view)
        
        let referenceImage = fromReferenceImageView.image!
        
        if self.transitionImageView == nil {
            let transitionImageView = UIImageView(image: referenceImage)
            transitionImageView.contentMode = .scaleAspectFill
            transitionImageView.clipsToBounds = true
            transitionImageView.frame = fromReferenceImageViewFrame
            self.transitionImageView = transitionImageView
            containerView.addSubview(transitionImageView)
        }
        
        fromReferenceImageView.isHidden = true
        
        let finalTransitionSize = calculateZoomInImageFrame(image: referenceImage, forView: toVC.view)
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: [UIView.AnimationOptions.transitionCrossDissolve],
                       animations: {
                        self.transitionImageView?.frame = finalTransitionSize
                        toVC.view.alpha = 1.0
                        fromVC.tabBarController?.tabBar.alpha = 0
        },
                       completion: { completed in
                    
                        self.transitionImageView?.removeFromSuperview()
                        toReferenceImageView.isHidden = false
                        fromReferenceImageView.isHidden = false
                        
                        self.transitionImageView = nil
                        
                        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                        self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
                        self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)
        })
    }
    
    fileprivate func animateZoomOutTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        
        guard let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
            let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
            let fromReferenceImageView = self.fromDelegate?.referenceImageView(for: self),
            let toReferenceImageView = self.toDelegate?.referenceImageView(for: self),
            let fromReferenceImageViewFrame = self.fromDelegate?.referenceImageViewFrameInTransitioningView(for: self),
            let toReferenceImageViewFrame = self.toDelegate?.referenceImageViewFrameInTransitioningView(for: self)
            else {
                return
        }
        
        self.fromDelegate?.transitionWillStartWith(zoomAnimator: self)
        self.toDelegate?.transitionWillStartWith(zoomAnimator: self)
        
        toReferenceImageView.isHidden = true
        
        let referenceImage = fromReferenceImageView.image!
        
        if self.transitionImageView == nil {
            let transitionImageView = UIImageView(image: referenceImage)
            transitionImageView.contentMode = .scaleAspectFill
            transitionImageView.clipsToBounds = true
            transitionImageView.frame = fromReferenceImageViewFrame
            self.transitionImageView = transitionImageView
            containerView.addSubview(transitionImageView)
        }
        
        containerView.insertSubview(toVC.view, belowSubview: fromVC.view)
        fromReferenceImageView.isHidden = true
        
        let finalTransitionSize = toReferenceImageViewFrame
        
        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       options: [],
                       animations: {
                        fromVC.view.alpha = 0
                        self.transitionImageView?.frame = finalTransitionSize
                        toVC.tabBarController?.tabBar.alpha = 1
        }, completion: { completed in
            
            self.transitionImageView?.removeFromSuperview()
            toReferenceImageView.isHidden = false
            fromReferenceImageView.isHidden = false
            
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            self.toDelegate?.transitionDidEndWith(zoomAnimator: self)
            self.fromDelegate?.transitionDidEndWith(zoomAnimator: self)

        })
    }
    
    private func calculateZoomInImageFrame(image: UIImage, forView view: UIView) -> CGRect {
        
        let viewRatio = view.frame.size.width / view.frame.size.height
        let imageRatio = image.size.width / image.size.height
        let touchesSides = (imageRatio > viewRatio)
        
        if touchesSides {
            let height = view.frame.width / imageRatio
            let yPoint = view.frame.minY + (view.frame.height - height) / 2
            return CGRect(x: 0, y: yPoint, width: view.frame.width, height: height)
        } else {
            let width = view.frame.height * imageRatio
            let xPoint = view.frame.minX + (view.frame.width - width) / 2
            return CGRect(x: xPoint, y: 0, width: width, height: view.frame.height)
        }
    }
}

extension ZoomAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        if self.isPresenting {
            return 0.5
        } else {
            return 0.25
        }
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if self.isPresenting {
            animateZoomInTransition(using: transitionContext)
        } else {
            animateZoomOutTransition(using: transitionContext)
        }
    }
}
