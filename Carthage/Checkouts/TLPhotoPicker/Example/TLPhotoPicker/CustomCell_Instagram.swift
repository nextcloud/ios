//
//  CustomCell_Instagram.swift
//  TLPhotoPicker
//
//  Created by wade.hawk on 2017. 5. 15..
//  Copyright © 2017년 CocoaPods. All rights reserved.
//

import Foundation
import TLPhotoPicker
import PhotosUI

class CustomCell_Instagram: TLPhotoCollectionViewCell {
    
    @IBOutlet var sizeRequiredLabel: UILabel!
    @IBOutlet var sizeRequiredOverlayView: UIView!
    
    let selectedColor = UIColor(red: 88/255, green: 144/255, blue: 255/255, alpha: 1.0)
    
    override var duration: TimeInterval? {
        didSet {
            self.durationLabel?.isHidden = self.duration == nil ? true : false
            guard let duration = self.duration else { return }
            self.durationLabel?.text = timeFormatted(timeInterval: duration)
        }
    }
    
    override var isCameraCell: Bool {
        didSet {
            self.orderLabel?.isHidden = self.isCameraCell
        }
    }
    
    override public var selectedAsset: Bool {
        willSet(newValue) {
            self.orderLabel?.layer.borderColor = newValue ? self.selectedColor.cgColor : UIColor.white.cgColor
            self.orderLabel?.backgroundColor = newValue ? self.selectedColor : UIColor(red: 1, green: 1, blue: 1, alpha: 0.3)
        }
    }
    
    override func update(with phAsset: PHAsset) {
        super.update(with: phAsset)
        self.sizeRequiredOverlayView?.isHidden = (phAsset.pixelWidth == 300 && phAsset.pixelHeight == 300)
        self.sizeRequiredLabel?.text = "\(phAsset.pixelWidth)\nx\n\(phAsset.pixelHeight)"
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.sizeRequiredOverlayView?.isHidden = true
        self.durationView?.backgroundColor = UIColor.clear
        self.orderLabel?.clipsToBounds = true
        self.orderLabel?.layer.cornerRadius = 10
        self.orderLabel?.layer.borderWidth = 1
        self.orderLabel?.layer.borderColor = UIColor.white.cgColor
    }
    
    override open func prepareForReuse() {
        super.prepareForReuse()
        self.durationView?.backgroundColor = UIColor.clear
    }
}
