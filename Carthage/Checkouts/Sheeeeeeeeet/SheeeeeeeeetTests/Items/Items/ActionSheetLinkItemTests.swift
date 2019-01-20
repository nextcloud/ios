//
//  ActionSheetLinkItemTests.swift
//  Sheeeeeeeeet
//
//  Created by Daniel Saidi on 2017-11-26.
//  Copyright © 2017 Daniel Saidi. All rights reserved.
//

import Quick
import Nimble
import Sheeeeeeeeet

class ActionSheetLinkItemTests: QuickSpec {
    
    override func spec() {
        
        describe("cell") {
            
            it("is of correct type") {
                let item = ActionSheetLinkItem(title: "foo")
                let cell = item.cell(for: UITableView())
                
                expect(cell is ActionSheetLinkItemCell).to(beTrue())
                expect(cell.reuseIdentifier).to(equal(item.cellReuseIdentifier))
            }
        }
    }
}


class ActionSheetLinkItemCellTests: QuickSpec {
    
    override func spec() {
        
        describe("refreshing") {
            
            it("applies accessory view with link icon") {
                let item = ActionSheetLinkItem(title: "foo")
                let cell = item.cell(for: UITableView()) as? ActionSheetLinkItemCell
                cell?.linkIcon = UIImage()
                cell?.refresh()
                let imageView = cell?.accessoryView as? UIImageView
                
                expect(imageView?.image).toNot(beNil())
                expect(imageView?.image).to(be(cell?.linkIcon))
            }
        }
    }
}
