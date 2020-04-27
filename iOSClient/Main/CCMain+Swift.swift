//
//  CCMain+Swift.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.04.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

extension CCMain {

    @objc func updateNavBarShadow(_ hide: Bool) {
        if hide {
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
