//
//  DropdownItem.swift
//  DropdownMenu
//
//  Created by Suric on 16/5/27.
//  Copyright © 2016年 teambition. All rights reserved.
//

import UIKit

public enum DropdownItemStyle: Int {
    case `default`
    case highlight
}

open class DropdownItem {
    open var image: UIImage?
    open var title: String
    open var style: DropdownItemStyle
    open var accessoryImage: UIImage?

    public init(image: UIImage? = nil, title: String, style: DropdownItemStyle = .default, accessoryImage: UIImage? = nil) {
        self.image = image
        self.title = title
        self.style = style
        self.accessoryImage = accessoryImage
    }
}

public struct DropdownSection {
    public var sectionIdentifier: String
    public var items: [DropdownItem]

    public init (sectionIdentifier: String, items: [DropdownItem]) {
        self.items = items
        self.sectionIdentifier = sectionIdentifier
    }
}
