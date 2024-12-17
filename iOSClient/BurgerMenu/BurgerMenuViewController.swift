//
//  BurgerMenuViewController.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 28.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import SwiftUI

class BurgerMenuViewController: UIHostingController<BurgerMenuView> {
    
    private var viewModel: BurgerMenuViewModel?
        
    convenience init(delegate: BurgerMenuViewModelDelegate?) {
        let viewModel = BurgerMenuViewModel(delegate: delegate, controller: nil)
        self.init(rootView: BurgerMenuView(viewModel: viewModel))
        viewModel.controller = self.mainTabBarController
        self.viewModel = viewModel
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel?.showMenu()
    }
}
