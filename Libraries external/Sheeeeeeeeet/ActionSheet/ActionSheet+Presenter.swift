//
//  ActionSheet+Presenter.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2018-04-27.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

public extension ActionSheet {
    
    static var defaultPresenter: ActionSheetPresenter {
        return defaultPresenter(for: UIDevice.current.userInterfaceIdiom)
    }
}


// MARK: - Internal Extensions

extension ActionSheet {
    
    static func defaultPresenter(for idiom: UIUserInterfaceIdiom) -> ActionSheetPresenter {
        let isIpad = idiom == .pad
        return isIpad ? ActionSheetPopoverPresenter() : ActionSheetDefaultPresenter()
    }
}
