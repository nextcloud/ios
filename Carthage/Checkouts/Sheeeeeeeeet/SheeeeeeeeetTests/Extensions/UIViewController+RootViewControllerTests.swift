//
//  UIViewController+RootViewControllerTests.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
@testable import Sheeeeeeeeet

class UIViewController_RootViewControllerTests: QuickSpec {
    
    override func spec() {
        
        describe("root view controller") {
            
            it("is self if no parent") {
                let vc = UIViewController()
                expect(vc.rootViewController).to(be(vc))
            }
            
            it("is navigation controller if view controller is embedded") {
                let vc = UIViewController()
                let nvc = UINavigationController(rootViewController: vc)
                expect(vc.rootViewController).to(be(nvc))
            }
            
            it("is tab bar controller if navigation controller is embedded") {
                let vc = UIViewController()
                let nvc = UINavigationController(rootViewController: vc)
                let tvc = UITabBarController()
                tvc.addChild(nvc)
                expect(vc.rootViewController).to(be(tvc))
            }
        }
    }
}
