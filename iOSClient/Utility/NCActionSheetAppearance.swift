//
//  NCActionSheetAppearance.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 30/09/19.
//  Copyright © 2018 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit
import Sheeeeeeeeet

/*
class NCAppearance: StandardActionSheetAppearance {

     override func applyColors() {
      
        ActionSheetTableView.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        ActionSheetTableView.appearance().separatorColor = NCBrandColor.sharedInstance.separator
        ActionSheetItemCell.appearance().backgroundColor = NCBrandColor.sharedInstance.backgroundForm
        ActionSheetItemCell.appearance().titleColor = NCBrandColor.sharedInstance.textView
    }
}
*/

// MARK: - Delete Cell

class ActionSheetDeleteItem: ActionSheetItem {
    override open func cell(for tableView: UITableView) -> ActionSheetItemCell {
        return ActionSheetDeleteItemCell(style: cellStyle, reuseIdentifier: cellReuseIdentifier)
    }
}

class ActionSheetDeleteItemCell: ActionSheetItemCell {}
