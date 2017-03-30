//
//  CCMainTabBarController.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//

import Foundation

class CCMainTabBarController : UITabBarController, UITabBarControllerDelegate {
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        delegate = self
    }
    
    //Delegate methods
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        
        let tabViewControllers = tabBarController.viewControllers!
        let fromView = tabBarController.selectedViewController!.view
        let toView = viewController.view
        
        if (fromView == toView) {
            return false
        }
        
        let fromIndex = tabViewControllers.index(of: tabBarController.selectedViewController!)
        let toIndex = tabViewControllers.index(of: viewController)
        
        let offScreenRight = CGAffineTransform(translationX: (toView?.frame.width)!, y: 0)
        let offScreenLeft = CGAffineTransform(translationX: -(toView?.frame.width)!, y: 0)
        
        // start the toView to the right of the screen
        
        if (toIndex! < fromIndex!) {
            toView?.transform = offScreenLeft
            fromView?.transform = offScreenRight
        } else {
            toView?.transform = offScreenRight
            fromView?.transform = offScreenLeft
        }
        
        fromView?.tag = 124
        toView?.addSubview(fromView!)
        
        self.view.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            
            toView?.transform = CGAffineTransform.identity
            
        }, completion: { finished in
            
            let subViews = toView?.subviews
            for subview in subViews!{
                if (subview.tag == 124) {
                    subview.removeFromSuperview()
                }
            }
            tabBarController.selectedIndex = toIndex!
            self.view.isUserInteractionEnabled = true
            
        })
        
        return true
    }
}

