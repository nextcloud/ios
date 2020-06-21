//
//  CCMain+Swift.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.04.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

extension CCMain {

    @objc func updateNavBarShadow(_ scrollView: UIScrollView, force: Bool) {
        if (scrollView.contentOffset.y > -self.viewRichWorkspace.topView.frame.size.height || self.searchController.isActive || force) {
            if #available(iOS 13.0, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                navBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                navBarAppearance.backgroundColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
                navBarAppearance.backgroundColor = NCBrandColor.sharedInstance.tabBar
                self.navigationController?.navigationBar.standardAppearance = navBarAppearance

            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                self.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandElement
                self.navigationController?.navigationBar.shadowImage = nil
                self.navigationController?.navigationBar.setValue(false, forKey: "hidesShadow")
            }
            self.navigationController?.navigationBar.setNeedsLayout()

        } else {
            if #available(iOS 13.0, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                navBarAppearance.titleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                navBarAppearance.backgroundColor = NCBrandColor.sharedInstance.backgroundView
                navBarAppearance.shadowColor = .clear
                navBarAppearance.shadowImage = UIImage()
                self.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
                navBarAppearance.backgroundColor = NCBrandColor.sharedInstance.tabBar
                self.navigationController?.navigationBar.standardAppearance = navBarAppearance
            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                self.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor : NCBrandColor.sharedInstance.textView]
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brandElement
                self.navigationController?.navigationBar.shadowImage = UIImage()
                self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
            }
            self.navigationController?.navigationBar.setNeedsLayout()
        }
    }
}
