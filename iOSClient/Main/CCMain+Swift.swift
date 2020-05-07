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
        if (scrollView.contentOffset.y > self.viewRichWorkspace.topView.frame.size.height || self.searchController.isActive || force) {
            if #available(iOS 13.0, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.backgroundColor = .systemBackground
                self.navigationController?.navigationBar.standardAppearance = navBarAppearance
                self.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brand
                self.navigationController?.navigationBar.shadowImage = nil
                self.navigationController?.navigationBar.setValue(false, forKey: "hidesShadow")
            }
            self.navigationController?.navigationBar.setNeedsLayout()

        } else {
            if #available(iOS 13.0, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.backgroundColor = .systemBackground
                navBarAppearance.shadowColor = .clear
                navBarAppearance.shadowImage = UIImage()
                self.navigationController?.navigationBar.standardAppearance = navBarAppearance
                self.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance
            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brand
                self.navigationController?.navigationBar.shadowImage = UIImage()
                self.navigationController?.navigationBar.setValue(true, forKey: "hidesShadow")
            }
            self.navigationController?.navigationBar.setNeedsLayout()
        }
    }
}
