//
//  ActionSheetPopoverPresenter.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-24.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 This presenter presents action sheets in a popover, just as
 regular UIAlertControllers are displayed on an iPad.
 
 Since popovers have an arrow that should use the same color
 as the rest of the popover view, this presenter will remove
 any header view and combine items and buttons into a single
 item section.
 
 */

import UIKit

open class ActionSheetPopoverPresenter: NSObject, ActionSheetPresenter {
    
    
    // MARK: - Properties
    
    open var events = ActionSheetPresenterEvents()
    open var isDismissableWithTapOnBackground = true
    
    var actionSheet: ActionSheet?
    weak var popover: UIPopoverPresentationController?
    
    
    // MARK: - ActionSheetPresenter
    
    public func dismiss(completion: @escaping () -> ()) {
        let dismissAction = { completion();  self.actionSheet = nil }
        let vc = actionSheet?.presentingViewController
        vc?.dismiss(animated: true) { dismissAction() } ?? dismissAction()
    }
    
    open func present(sheet: ActionSheet, in vc: UIViewController, from view: UIView?, completion: @escaping () -> ()) {
        setupSheetForPresentation(sheet)
        popover = self.popover(for: sheet, in: vc)
        popover?.sourceView = view
        popover?.sourceRect = view?.bounds ?? CGRect()
        vc.present(sheet, animated: true, completion: completion)
    }
    
    open func present(sheet: ActionSheet, in vc: UIViewController, from item: UIBarButtonItem, completion: @escaping () -> ()) {
        setupSheetForPresentation(sheet)
        popover = self.popover(for: sheet, in: vc)
        popover?.barButtonItem = item
        vc.present(sheet, animated: true, completion: completion)
    }
    
    open func refreshActionSheet() {
        guard let sheet = actionSheet else { return }
        sheet.headerViewContainer?.isHidden = true
        sheet.buttonsTableView?.isHidden = true
        sheet.preferredContentSize.height = sheet.itemsHeight
        popover?.backgroundColor = sheet.itemsTableView?.backgroundColor
    }
}


// MARK: - UIPopoverPresentationControllerDelegate

extension ActionSheetPopoverPresenter: UIPopoverPresentationControllerDelegate {
    
    public func popoverPresentationControllerShouldDismissPopover(_ controller: UIPopoverPresentationController) -> Bool {
        guard isDismissableWithTapOnBackground else { return false }
        events.didDismissWithBackgroundTap?()
        dismiss {}
        return false
    }
}


// MARK: - Internal Functions

extension ActionSheetPopoverPresenter {
    
    func popover(for sheet: ActionSheet, in vc: UIViewController) -> UIPopoverPresentationController? {
        let popover = sheet.popoverPresentationController
        popover?.delegate = self
        return popover
    }
    
    func setupSheetForPresentation(_ sheet: ActionSheet) {
        self.actionSheet = sheet
        sheet.items = popoverItems(for: sheet)
        sheet.buttons = []
        sheet.modalPresentationStyle = .popover
    }
}


// MARK: - Private Functions

private extension ActionSheetPopoverPresenter {
    
    func popoverItems(for sheet: ActionSheet) -> [ActionSheetItem] {
        let items: [ActionSheetItem] = sheet.items + sheet.buttons
        return items.filter { !($0 is ActionSheetCancelButton) }
    }
}
