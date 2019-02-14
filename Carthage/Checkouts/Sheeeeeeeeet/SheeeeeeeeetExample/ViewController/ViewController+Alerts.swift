//
//  ViewController+Alerts.swift
//  SheeeeeeeeetExample
//
//  Created by Daniel Saidi on 2017-11-27.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

/*
 
 These extensions are only used by the example app, to alert
 which options a user selects in the example action sheets.
 
 */

import UIKit
import Sheeeeeeeeet

extension ViewController {
    
    func alert(button: UIButton) {
        alertSelection(button.title(for: .normal) ?? "None")
    }
    
    func alert(item: ActionSheetItem) {
        alert(items: [item])
    }
    
    func alert(items: [ActionSheetItem]) {
        let items = items.filter { !($0 is ActionSheetButton) }
        guard items.count > 0 else { return }
        alertSelection(items.map { $0.title }.joined(separator: " + "))
    }
    
    func alert(items: [MyCollectionViewCell.Item]) {
        guard items.count > 0 else { return }
        alertSelection(items.map { $0.title }.joined(separator: " + "))
    }
    
    func alert(title: String?, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(ok)
        present(alert, animated: true, completion: nil)
    }
    
    func alertSelection(_ value: String) {
        self.alert(title: "You selected:", message: value)
    }
}
