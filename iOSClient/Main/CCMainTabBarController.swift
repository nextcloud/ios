//
//  CCMainTabBarController.swift
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 30/03/17.
//  Copyright © 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
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
        guard let toIndex = tabViewControllers.index(of: viewController) else {
            
            if let vc = viewController as? UINavigationController {
                vc.popToRootViewController(animated: true);
            }
            
            return false
        }
        
        animateToTab(toIndex: toIndex)
        
        return true
    }
    
    func animateToTab(toIndex: Int) {
        
        let tabViewControllers = viewControllers!
        let fromView = selectedViewController!.view!
        let toView = tabViewControllers[toIndex].view!
        let fromIndex = tabViewControllers.index(of: selectedViewController!)
        
        guard fromIndex != toIndex else {return}
        
        // Add the toView to the tab bar view
        fromView.superview?.addSubview(toView)
        fromView.superview?.backgroundColor = UIColor.white
        
        // Position toView off screen (to the left/right of fromView)
        let screenWidth = UIScreen.main.bounds.size.width;
        let scrollRight = toIndex > fromIndex!;
        let offset = (scrollRight ? screenWidth : -screenWidth)
        toView.center = CGPoint(x: (fromView.center.x) + offset, y: (toView.center.y))
        
        // Disable interaction during animation
        view.isUserInteractionEnabled = false
        
        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: UIViewAnimationOptions.curveEaseOut, animations: {
            
            // Slide the views by -offset
            fromView.center = CGPoint(x: fromView.center.x - offset, y: fromView.center.y);
            toView.center   = CGPoint(x: toView.center.x - offset, y: toView.center.y);
            
        }, completion: { finished in
            
            // Remove the old view from the tabbar view.
            fromView.removeFromSuperview()
            self.selectedIndex = toIndex
            self.view.isUserInteractionEnabled = true
        })
    }

}

