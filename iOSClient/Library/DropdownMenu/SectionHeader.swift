//
//  SectionHeader.swift
//  DropdownMenu
//
//  Created by WangWei on 2016/10/9.
//  Copyright © 2016年 teambition. All rights reserved.
//

open class SectionHeader: UIView {
    var titleLabel: UILabel!
    var style: SectionHeaderStyle = SectionHeaderStyle()

    convenience init(style: SectionHeaderStyle) {
        self.init(frame: CGRect.zero)
        self.style = style
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func commonInit() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = style.font
        titleLabel.textColor = style.textColor
        backgroundColor = style.backgroundColor
        addSubview(titleLabel)
        updateTitleLabelConstraint()
    }

    func updateTitleLabelConstraint() {
        if #available(iOS 11.0, *) {
            let leftConstraint = NSLayoutConstraint(item: titleLabel, attribute: .left, relatedBy: .equal, toItem: safeAreaLayoutGuide, attribute: .left, multiplier: 1.0, constant: style.bottomPadding)
            NSLayoutConstraint.activate([leftConstraint])
        } else {
            // Fallback on earlier versions
            let constraints =  NSLayoutConstraint.constraints(withVisualFormat: "H:|-leftPadding-[titleLabel]->=20-|", options: [], metrics: ["leftPadding": style.leftPadding], views: ["titleLabel": titleLabel])
            addConstraints(constraints)
        }
        if style.shouldTitleCenterVertically {
            let centerY = NSLayoutConstraint(item: titleLabel, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0)
            addConstraint(centerY)
        } else {
            let vConstraints = NSLayoutConstraint(item: titleLabel, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: style.bottomPadding)
            addConstraint(vConstraints)
        }
    }
}


public struct SectionHeaderStyle {
    
    /// leftPadding for title label, default is `20`
    public var leftPadding: CGFloat = 20
    /// bottom padding for title label, default is `10`,
    /// will be ignored when `shouldTitleCenterVertically` is `true`
    public var bottomPadding: CGFloat = 10
    /// should title label center in axis Y, default is `true`
    public var shouldTitleCenterVertically: Bool = true

    /// title label font, default is `UIFont.systemFont(ofSize: 14)`
    public var font: UIFont = UIFont.systemFont(ofSize: 14)
    /// title label textColor, default is A6A6A6
    public var textColor: UIColor = UIColor(red: 166.0/255.0, green: 166.0/255.0, blue: 166.0/255.0, alpha: 1.0)
    /// backgroundColor for header, default is F2F2F2
    public var backgroundColor: UIColor = UIColor(red: 242.0/255.0, green: 242.0/255.0, blue: 242.0/255.0, alpha: 1.0)

    public init() {
    }
}
