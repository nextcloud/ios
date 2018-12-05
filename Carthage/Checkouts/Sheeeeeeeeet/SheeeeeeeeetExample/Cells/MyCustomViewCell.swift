//
//  MyCustomViewCell.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi on 2018-10-08.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import Sheeeeeeeeet

class MyCustomViewCell: ActionSheetItemCell, ActionSheetCustomItemCell {
    
    
    // MARK: - ActionSheetCustomItemCell
    
    static let nib: UINib = UINib(nibName: "MyCustomViewCell", bundle: nil)
    static let defaultSize = CGSize(width: 100, height: 400)
    
    
    // MARK: - Properties
    
    var buttonTapAction: ((UIButton) -> ())?
    

    // MARK: - Outlets
    
    @IBOutlet weak var leftButton: UIButton!
    @IBOutlet weak var centerButton: UIButton!
    @IBOutlet weak var rightButton: UIButton!
    
    
    // MARK: - Actions
    
    @IBAction func buttonTapAction(_ sender: UIButton) {
        buttonTapAction?(sender)
    }
}
