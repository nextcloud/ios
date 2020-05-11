//
//  AppDelegate+Swift.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.04.20.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
//

import Foundation

extension AppDelegate {

    @objc func configureNavBarForViewController(_ viewController: UIViewController) {
        if #available(iOS 13.0, *) {
            var navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.shadowColor = .clear
            navBarAppearance.shadowImage = UIImage()
            viewController.navigationController?.navigationBar.scrollEdgeAppearance = navBarAppearance

            navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = .systemBackground

            viewController.navigationController?.navigationBar.standardAppearance = navBarAppearance
        } else {
            viewController.navigationController?.navigationBar.barStyle = .default
            viewController.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.backgroundView
            viewController.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor:NCBrandColor.sharedInstance.textView]
            if #available(iOS 11.0, *) {
                viewController.navigationController?.navigationBar.largeTitleTextAttributes = [NSAttributedString.Key.foregroundColor:NCBrandColor.sharedInstance.textView]
            }
        }
        viewController.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.brand
    }
    
}
