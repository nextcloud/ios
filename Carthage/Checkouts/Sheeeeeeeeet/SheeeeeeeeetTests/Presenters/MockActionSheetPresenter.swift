//
//  MockActionSheetPresenter.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-04-27.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Sheeeeeeeeet

class MockActionSheetPresenter: ActionSheetPresenter {
    
    var events = ActionSheetPresenterEvents()
    var isDismissableWithTapOnBackground = false
    
    var dismissInvokeCount = 0
    var dismissInvokeCompletions = [() -> ()]()
    var presentInvokeCount = 0
    var presentInvokeCompletions = [() -> ()]()
    var presentInvokeSheets = [ActionSheet]()
    var presentInvokeViewControllers = [UIViewController]()
    var presentInvokeViews = [UIView?]()
    var presentInvokeItems = [UIBarButtonItem]()
    var refreshActionSheetInvokeCount = 0
    
    func dismiss(completion: @escaping () -> ()) {
        dismissInvokeCount += 1
        dismissInvokeCompletions.append(completion)
    }
    
    func present(sheet: ActionSheet, in vc: UIViewController, from view: UIView?, completion: @escaping () -> ()) {
        presentInvokeCount += 1
        presentInvokeSheets.append(sheet)
        presentInvokeViewControllers.append(vc)
        presentInvokeViews.append(view)
        presentInvokeCompletions.append(completion)
    }
    
    func present(sheet: ActionSheet, in vc: UIViewController, from item: UIBarButtonItem, completion: @escaping () -> ()) {
        presentInvokeCount += 1
        presentInvokeSheets.append(sheet)
        presentInvokeViewControllers.append(vc)
        presentInvokeItems.append(item)
        presentInvokeCompletions.append(completion)
    }
    
    func refreshActionSheet() {
        refreshActionSheetInvokeCount += 1
    }
}
