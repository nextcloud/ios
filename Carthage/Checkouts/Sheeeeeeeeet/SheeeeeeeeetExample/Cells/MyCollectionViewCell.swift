//
//  MyCollectionViewCell.swift
//  SheeeeeeeeetExample
//
//  Created by Jonas Ullström (ullstrm) on 2018-02-23.
//  Copyright © 2018 Jonas Ullström. All rights reserved.
//

import UIKit
import Sheeeeeeeeet

class MyCollectionViewCell: UICollectionViewCell {
    
    
    // MARK: - Overrides
    
    override func layoutSubviews() {
        super.layoutSubviews()
        badge?.layer.cornerRadius = 20
    }
    
    
    // MARK: - Item
    
    class Item: Equatable {
        
        init(title: String, subtitle: String) {
            self.title = title
            self.subtitle = subtitle
            self.isSelected = false
        }
        
        init(copy: Item) {
            self.title = copy.title
            self.subtitle = copy.subtitle
            self.isSelected = copy.isSelected
        }
        
        var title: String
        var subtitle: String
        var isSelected: Bool

        static func == (lhs: Item, rhs: Item) -> Bool {
            return lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
        }
    }
    
    
    // MARK: - Outlets
    
    @IBOutlet weak var badge: UIView?
    
    @IBOutlet weak var titleLabel: UILabel?
    
    
    // MARK: - Public Functions
    
    func configureWith(item: Item) {
        let green = UIColor(hex: 0x4EA32A, alpha: 1)
        titleLabel?.text = item.title
        titleLabel?.textColor = item.isSelected ? .white : .black
        badge?.backgroundColor = item.isSelected ? green : .lightGray
    }
}


// MARK: - ActionSheetCollectionItemContentCell

extension MyCollectionViewCell: ActionSheetCollectionItemContentCell {
    
    static let nib: UINib = UINib(nibName: "MyCollectionViewCell", bundle: nil)
    static let defaultSize = CGSize(width: 100, height: 100)
    static let leftInset: CGFloat = 10
    static let rightInset: CGFloat = 20
    static let topInset: CGFloat = 10
    static let bottomInset: CGFloat = 10
    static let itemSpacing: CGFloat = 0
}
