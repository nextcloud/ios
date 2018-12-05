//
//  ActionSheetStandardPresenter.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This presenter will present action sheets as regular iPhone
 action sheets, from the bottom of the screen.
 
 */

import UIKit

open class ActionSheetStandardPresenter: ActionSheetPresenter {
    
    
    // MARK: - Initialization
    
    public init() {}
    
    deinit { print("\(type(of: self)) deinit") }
    
    
    // MARK: - Properties
    
    public var events = ActionSheetPresenterEvents()
    public var isDismissableWithTapOnBackground = true
    
    private var actionSheet: ActionSheet?
    
    
    // MARK: - ActionSheetPresenter
    
    open func dismiss(completion: @escaping () -> ()) {
        completion()
        removeBackgroundView()
        removeActionSheet {
            self.actionSheet?.view.removeFromSuperview()
            self.actionSheet = nil
        }
    }
    
    open func present(sheet: ActionSheet, in vc: UIViewController, from view: UIView?, completion: @escaping () -> ()) {
        present(sheet: sheet, in: vc, completion: completion)
    }
    
    open func present(sheet: ActionSheet, in vc: UIViewController, from item: UIBarButtonItem, completion: @escaping () -> ()) {
        present(sheet: sheet, in: vc, completion: completion)
    }
    
    open func present(sheet: ActionSheet, in vc: UIViewController, completion: @escaping () -> ()) {
        actionSheet = sheet
        addActionSheetView(from: sheet, to: vc.view)
        presentBackgroundView()
        presentActionSheet(completion: completion)
    }
    
    open func refreshActionSheet() {
        guard let sheet = actionSheet else { return }
        sheet.topMargin?.constant = sheet.margin(at: .top)
        sheet.leftMargin?.constant = sheet.margin(at: .left)
        sheet.rightMargin?.constant = sheet.margin(at: .right)
        sheet.bottomMargin?.constant = sheet.margin(at: .bottom)
    }
    
    
    // MARK: - Protected Functions
    
    open func addActionSheetView(from sheet: ActionSheet, to view: UIView) {
        sheet.view.frame = view.frame
        view.addSubview(sheet.view)
        addBackgroundViewTapAction(to: sheet.backgroundView)
    }

    open func addBackgroundViewTapAction(to view: UIView?) {
        view?.isUserInteractionEnabled = true
        let action = #selector(backgroundViewTapAction)
        let tap = UITapGestureRecognizer(target: self, action: action)
        view?.addGestureRecognizer(tap)
    }
    
    open func animate(_ animation: @escaping () -> ()) {
        animate(animation, completion: nil)
    }
    
    open func animate(_ animation: @escaping () -> (), completion: (() -> ())?) {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: animation) { _ in completion?() }
    }
    
    open func presentActionSheet(completion: @escaping () -> ()) {
        guard let view = actionSheet?.stackView else { return }
        let frame = view.frame
        view.frame.origin.y += frame.height + 100
        let animation = { view.frame = frame }
        animate(animation, completion: completion)
    }
    
    open func presentBackgroundView() {
        guard let view = actionSheet?.backgroundView else { return }
        view.alpha = 0
        let animation = { view.alpha = 1 }
        animate(animation)
    }

    open func removeActionSheet(completion: @escaping () -> ()) {
        guard let view = actionSheet?.stackView else { return }
        let frame = view.frame
        let animation = { view.frame.origin.y += frame.height + 100 }
        animate(animation) { completion() }
    }

    open func removeBackgroundView() {
        guard let view = actionSheet?.backgroundView else { return }
        let animation = { view.alpha = 0 }
        animate(animation)
    }
}


// MARK: - Actions

@objc public extension ActionSheetStandardPresenter {
    
    public func backgroundViewTapAction() {
        guard isDismissableWithTapOnBackground else { return }
        events.didDismissWithBackgroundTap?()
        dismiss {}
    }
}
