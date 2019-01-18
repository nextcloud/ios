//
//  CropViewController.swift
//  CropViewController
//
//  Created by Guilherme Moura on 2/25/16.
//  Copyright © 2016 Reefactor, Inc. All rights reserved.
// Credit https://github.com/sprint84/PhotoCropEditor

import UIKit

public protocol CropViewControllerDelegate: class {
    func cropViewController(_ controller: CropViewController, didFinishCroppingImage image: UIImage, transform: CGAffineTransform, cropRect: CGRect)
    func cropViewControllerDidCancel(_ controller: CropViewController)
}

open class CropViewController: UIViewController {
    open weak var delegate: CropViewControllerDelegate?
    open var image: UIImage? {
        didSet {
            cropView?.image = image
        }
    }
    open var keepAspectRatio = false {
        didSet {
            cropView?.keepAspectRatio = keepAspectRatio
        }
    }
    open var cropAspectRatio: CGFloat = 0.0 {
        didSet {
            cropView?.cropAspectRatio = cropAspectRatio
        }
    }
    open var cropRect = CGRect.zero {
        didSet {
            adjustCropRect()
        }
    }
    open var imageCropRect = CGRect.zero {
        didSet {
            cropView?.imageCropRect = imageCropRect
        }
    }
    open var toolbarHidden = false
    open var rotationEnabled = false {
        didSet {
            cropView?.rotationGestureRecognizer.isEnabled = rotationEnabled
        }
    }
    open var rotationTransform: CGAffineTransform {
        return cropView!.rotation
    }
    open var zoomedCropRect: CGRect {
        return cropView!.zoomedCropRect()
    }

    fileprivate var cropView: CropView?
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        initialize()
    }
    
    fileprivate func initialize() {
        rotationEnabled = true
    }
    
    open override func loadView() {
        let contentView = UIView()
        contentView.autoresizingMask = .flexibleWidth
        contentView.backgroundColor = UIColor.black
        view = contentView
        
        // Add CropView
        cropView = CropView(frame: contentView.bounds)
        contentView.addSubview(cropView!)
        
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.isTranslucent = false
        navigationController?.toolbar.isTranslucent = false
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(CropViewController.cancel(_:)))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(CropViewController.done(_:)))
        
        if self.toolbarItems == nil {
            let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            let constrainButton = UIBarButtonItem(title: "Constrain", style: .plain, target: self, action: #selector(CropViewController.constrain(_:)))
            toolbarItems = [flexibleSpace, constrainButton, flexibleSpace]
        }
        
        navigationController?.isToolbarHidden = toolbarHidden
        
        cropView?.image = image
        cropView?.rotationGestureRecognizer.isEnabled = rotationEnabled
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if cropAspectRatio != 0 {
            cropView?.cropAspectRatio = cropAspectRatio
        }
        
        if !cropRect.equalTo(CGRect.zero) {
            adjustCropRect()
        }
        
        if !imageCropRect.equalTo(CGRect.zero) {
            cropView?.imageCropRect = imageCropRect
        }
        
        cropView?.keepAspectRatio = keepAspectRatio
    }
    
    open func resetCropRect() {
        cropView?.resetCropRect()
    }
    
    open func resetCropRectAnimated(_ animated: Bool) {
        cropView?.resetCropRectAnimated(animated)
    }
    
    @objc func cancel(_ sender: UIBarButtonItem) {
        delegate?.cropViewControllerDidCancel(self)
    }
    
    @objc func done(_ sender: UIBarButtonItem) {
        if let image = cropView?.croppedImage {
            guard let rotation = cropView?.rotation else {
                return
            }
            guard let rect = cropView?.zoomedCropRect() else {
                return
            }
            delegate?.cropViewController(self, didFinishCroppingImage: image, transform: rotation, cropRect: rect)
        }
    }
    
    @objc func constrain(_ sender: UIBarButtonItem) {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let original = UIAlertAction(title: "Original", style: .default) { [unowned self] action in
            guard let image = self.cropView?.image else {
                return
            }
            guard var cropRect = self.cropView?.cropRect else {
                return
            }
            let width = image.size.width
            let height = image.size.height
            let ratio: CGFloat
            if width < height {
                ratio = width / height
                cropRect.size = CGSize(width: cropRect.height * ratio, height: cropRect.height)
            } else {
                ratio = height / width
                cropRect.size = CGSize(width: cropRect.width, height: cropRect.width * ratio)
            }
            self.cropView?.cropRect = cropRect
        }
        actionSheet.addAction(original)
        let square = UIAlertAction(title: "Square", style: .default) { [unowned self] action in
            let ratio: CGFloat = 1.0
//            self.cropView?.cropAspectRatio = ratio
            if var cropRect = self.cropView?.cropRect {
                let width = cropRect.width
                cropRect.size = CGSize(width: width, height: width * ratio)
                self.cropView?.cropRect = cropRect
            }
        }
        actionSheet.addAction(square)
        let threeByTwo = UIAlertAction(title: "3 x 2", style: .default) { [unowned self] action in
            self.cropView?.cropAspectRatio = 2.0 / 3.0
        }
        actionSheet.addAction(threeByTwo)
        let threeByFive = UIAlertAction(title: "3 x 5", style: .default) { [unowned self] action in
            self.cropView?.cropAspectRatio = 3.0 / 5.0
        }
        actionSheet.addAction(threeByFive)
        let fourByThree = UIAlertAction(title: "4 x 3", style: .default) { [unowned self] action in
            let ratio: CGFloat = 3.0 / 4.0
            if var cropRect = self.cropView?.cropRect {
                let width = cropRect.width
                cropRect.size = CGSize(width: width, height: width * ratio)
                self.cropView?.cropRect = cropRect
            }
        }
        actionSheet.addAction(fourByThree)
        let fourBySix = UIAlertAction(title: "4 x 6", style: .default) { [unowned self] action in
            self.cropView?.cropAspectRatio = 4.0 / 6.0
        }
        actionSheet.addAction(fourBySix)
        let fiveBySeven = UIAlertAction(title: "5 x 7", style: .default) { [unowned self] action in
            self.cropView?.cropAspectRatio = 5.0 / 7.0
        }
        actionSheet.addAction(fiveBySeven)
        let eightByTen = UIAlertAction(title: "8 x 10", style: .default) { [unowned self] action in
            self.cropView?.cropAspectRatio = 8.0 / 10.0
        }
        actionSheet.addAction(eightByTen)
        let widescreen = UIAlertAction(title: "16 x 9", style: .default) { [unowned self] action in
            let ratio: CGFloat = 9.0 / 16.0
            if var cropRect = self.cropView?.cropRect {
                let width = cropRect.width
                cropRect.size = CGSize(width: width, height: width * ratio)
                self.cropView?.cropRect = cropRect
            }
        }
        actionSheet.addAction(widescreen)
        let cancel = UIAlertAction(title: "Cancel", style: .default) { [unowned self] action in
            self.dismiss(animated: true, completion: nil)
        }
        actionSheet.addAction(cancel)
        
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.barButtonItem = sender
        }
        
        present(actionSheet, animated: true, completion: nil)
    }

    // MARK: - Private methods
    fileprivate func adjustCropRect() {
        imageCropRect = CGRect.zero
        
        guard var cropViewCropRect = cropView?.cropRect else {
            return
        }
        cropViewCropRect.origin.x += cropRect.origin.x
        cropViewCropRect.origin.y += cropRect.origin.y
        
        let minWidth = min(cropViewCropRect.maxX - cropViewCropRect.minX, cropRect.width)
        let minHeight = min(cropViewCropRect.maxY - cropViewCropRect.minY, cropRect.height)
        let size = CGSize(width: minWidth, height: minHeight)
        cropViewCropRect.size = size
        cropView?.cropRect = cropViewCropRect
    }
    
    

}
