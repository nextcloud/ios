//
//  ActionSheetPresenter.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-18.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 Action sheet presenters are used to present and dismiss any
 action sheet in different ways, for instance with a default
 slide-in, showing the sheet in a popover etc.
 
 Instead of a delegate, the presenter protocol uses an event
 property that has events that you can subscribe to, by just
 setting the action blocks in the event struct.
 
 */

import Foundation

public struct ActionSheetPresenterEvents {
    
    public init() {}
    
    public var didDismissWithBackgroundTap: (() -> ())?
}

public protocol ActionSheetPresenter: AnyObject {
    
    var events: ActionSheetPresenterEvents { get set }
    var isDismissableWithTapOnBackground: Bool { get set }
    
    func dismiss(completion: @escaping () -> ())
    func present(sheet: ActionSheet, in vc: UIViewController, from view: UIView?, completion: @escaping () -> ())
    func present(sheet: ActionSheet, in vc: UIViewController, from item: UIBarButtonItem, completion: @escaping () -> ())
    func refreshActionSheet()
}
