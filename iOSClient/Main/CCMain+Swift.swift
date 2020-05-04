//
//  CCMain+Swift.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.04.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

extension CCMain {

    @objc func updateNavBarShadow(_ scrollView: UIScrollView) {
        if(self.searchController.isActive && scrollView.contentOffset.y > 44) {
            let searchBar = self.searchController.searchBar
            if(searchBar.layer.sublayers!.count < 2) {
                let border = CALayer()

                border.backgroundColor = UIColor.lightGray.withAlphaComponent(0.6).cgColor
                border.frame = CGRect(x: 0, y: searchBar.frame.height - 1, width: searchBar.frame.size.width, height: 1)
                searchBar.layer.addSublayer(border)
            }
        } else {
            let searchBar = self.searchController.searchBar
            if(searchBar.layer.sublayers!.count > 1) {
                searchBar.layer.sublayers?.removeLast()
            }
        }

        if (scrollView.contentOffset.y > self.viewRichWorkspace.topView.frame.size.height) {
            if #available(iOS 13.0, *) {
                let navBarAppearance = UINavigationBarAppearance()
                navBarAppearance.configureWithOpaqueBackground()
                navBarAppearance.backgroundColor = .systemBackground
                self.navigationController?.navigationBar.standardAppearance = navBarAppearance
            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brand
                self.navigationController?.navigationBar.shadowImage = nil
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
            } else {
                self.navigationController?.navigationBar.barStyle = .default
                self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
                self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brand
                self.navigationController?.navigationBar.shadowImage = UIImage()
            }
            self.navigationController?.navigationBar.setNeedsLayout()
        }
    }
}
