//
//  MockTableView.swift
//  SheeeeeeeeetTests
//
//  Created by Daniel Saidi on 2018-10-17.
//  Copyright © 2018 Daniel Saidi. All rights reserved.
//

import UIKit

class MockTableView: UITableView {

    var deselectRowInvokeCount = 0
    var deselectRowInvokePaths = [IndexPath]()
    var deselectRowInvokeAnimated = [Bool]()
    var reloadDataInvokeCount = 0
    
    override func deselectRow(at indexPath: IndexPath, animated: Bool) {
        deselectRowInvokeCount += 1
        deselectRowInvokePaths.append(indexPath)
        deselectRowInvokeAnimated.append(animated)
    }
    
    override func reloadData() {
        super.reloadData()
        reloadDataInvokeCount += 1
    }
}
