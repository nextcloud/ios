//
//  MainMenuAction.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 16.01.20.
//  Copyright © 2020 TWS. All rights reserved.
//

import Foundation

class MenuAction {
    
    let title: String
    let icon: UIImage
    let value: Int
    
    init(title: String, value: Int, icon: UIImage) {
        self.title = title
        self.icon = icon
        self.value = value
    }
}
