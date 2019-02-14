//
//  CropView.swift
//  CropViewController
//
//  Created by Guilherme Moura on 2/25/16.
//  Copyright © 2016 Reefactor, Inc. All rights reserved.
// Credit https://github.com/sprint84/PhotoCropEditor

import UIKit
import AVFoundation

open class CropView: UIView, UIScrollViewDelegate, UIGestureRecognizerDelegate, CropRectViewDelegate {
    open var image: UIImage? {
        didSet {
            if image != nil {
                imageSize = image!.size
            }
            imageView?.removeFromSuperview()
            imageView = nil
            zoomingView?.removeFromSuperview()
            zoomingView = nil
            setNeedsLayout()
        }
    }
    open var imageView: UIView? {
        didSet {
            if let view = imageView , image == nil {
                imageSize = view.frame.size
            }
            usingCustomImageView = true
            setNeedsLayout()
        }
    }
    open var croppedImage: UIImage? {
        return image?.rotatedImageWithTransform(rotation, croppedToRect: zoomedCropRect())
    }
    open var keepAspectRatio = false {
        didSet {
            cropRectView.keepAspectRatio = keepAspectRatio
        }
    }
    open var cropAspectRatio: CGFloat {
        set {
            setCropAspectRatio(newValue, shouldCenter: true)
        }
        get {
            let rect = scrollView.frame
            let width = rect.width
            let height = rect.height
            return width / height
        }
    }
    open var rotation: CGAffineTransform {
        guard let imgView = imageView else {
            return CGAffineTransform.identity
        }
        return imgView.transform
    }
    open var rotationAngle: CGFloat {
        set {
            imageView?.transform = CGAffineTransform(rotationAngle: newValue)
        }
        get {
            return atan2(rotation.b, rotation.a)
        }
    }
    open var cropRect: CGRect {
        set {
            zoomToCropRect(newValue)
        }
        get {
            return scrollView.frame
        }
    }
    open var imageCropRect = CGRect.zero {
        didSet {
            resetCropRect()
            
            let scale = min(scrollView.frame.width / imageSize.width, scrollView.frame.height / imageSize.height)
            let x = imageCropRect.minX * scale + scrollView.frame.minX
            let y = imageCropRect.minY * scale + scrollView.frame.minY
            let width = imageCropRect.width * scale
            let height = imageCropRect.height * scale
            
            let rect = CGRect(x: x, y: y, width: width, height: height)
            let intersection = rect.intersection(scrollView.frame)
            
            if !intersection.isNull {
                cropRect = intersection
            }
        }
    }
    open var resizeEnabled = true {
        didSet {
            cropRectView.enableResizing(resizeEnabled)
        }
    }
    open var showCroppedArea = true {
        didSet {
            layoutIfNeeded()
            scrollView.clipsToBounds = !showCroppedArea
            showOverlayView(showCroppedArea)
        }
    }
    open var rotationGestureRecognizer: UIRotationGestureRecognizer!
    fileprivate var imageSize = CGSize(width: 1.0, height: 1.0)
    fileprivate var scrollView: UIScrollView!
    fileprivate var zoomingView: UIView?
    fileprivate let cropRectView = CropRectView()
    fileprivate let topOverlayView = UIView()
    fileprivate let leftOverlayView = UIView()
    fileprivate let rightOverlayView = UIView()
    fileprivate let bottomOverlayView = UIView()
    fileprivate var insetRect = CGRect.zero
    fileprivate var editingRect = CGRect.zero
    fileprivate var interfaceOrientation = UIApplication.shared.statusBarOrientation
    fileprivate var resizing = false
    fileprivate var usingCustomImageView = false
    fileprivate let MarginTop: CGFloat = 37.0
    fileprivate let MarginLeft: CGFloat = 20.0

    public override init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }

    fileprivate func initialize() {
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = UIColor.clear
        
        scrollView = UIScrollView(frame: bounds)
        scrollView.delegate = self
        scrollView.autoresizingMask = [.flexibleTopMargin, .flexibleLeftMargin, .flexibleBottomMargin, .flexibleRightMargin]
        scrollView.backgroundColor = UIColor.clear
        scrollView.maximumZoomScale = 20.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.bouncesZoom = false
        scrollView.clipsToBounds =  false
        addSubview(scrollView)
        
        rotationGestureRecognizer = UIRotationGestureRecognizer(target: self, action: #selector(CropView.handleRotation(_:)))
        rotationGestureRecognizer?.delegate = self
        scrollView.addGestureRecognizer(rotationGestureRecognizer)
        
        cropRectView.delegate = self
        addSubview(cropRectView)
        
        showOverlayView(showCroppedArea)
        addSubview(topOverlayView)
        addSubview(leftOverlayView)
        addSubview(rightOverlayView)
        addSubview(bottomOverlayView)
    }
    
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !isUserInteractionEnabled {
            return nil
        }
        
        if let hitView = cropRectView.hitTest(convert(point, to: cropRectView), with: event) {
            return hitView
        }
        let locationInImageView = convert(point, to: zoomingView)
        let zoomedPoint = CGPoint(x: locationInImageView.x * scrollView.zoomScale, y: locationInImageView.y * scrollView.zoomScale)
        if zoomingView!.frame.contains(zoomedPoint) {
            return scrollView
        }
        return super.hitTest(point, with: event)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        
        if image == nil && imageView == nil {
            return
        }
        
        setupEditingRect()

        if imageView == nil {
            if interfaceOrientation.isPortrait {
                insetRect = bounds.insetBy(dx: MarginLeft, dy: MarginTop)
            } else {
                insetRect = bounds.insetBy(dx: MarginLeft, dy: MarginLeft)
            }
            if !showCroppedArea {
                insetRect = editingRect
            }
            setupZoomingView()
            setupImageView()
        } else if usingCustomImageView {
            if interfaceOrientation.isPortrait {
                insetRect = bounds.insetBy(dx: MarginLeft, dy: MarginTop)
            } else {
                insetRect = bounds.insetBy(dx: MarginLeft, dy: MarginLeft)
            }
            if !showCroppedArea {
                insetRect = editingRect
            }
            setupZoomingView()
            imageView?.frame = zoomingView!.bounds
            zoomingView?.addSubview(imageView!)
            usingCustomImageView = false
        }
        
        if !resizing {
            layoutCropRectViewWithCropRect(scrollView.frame)
            if self.interfaceOrientation != interfaceOrientation {
                zoomToCropRect(scrollView.frame)
            }
        }
        
        
        self.interfaceOrientation = interfaceOrientation
    }
    
    open func setRotationAngle(_ rotationAngle: CGFloat, snap: Bool) {
        var rotation = rotationAngle
        if snap {
            rotation = nearbyint(rotationAngle / CGFloat(Double.pi/2)) * CGFloat(Double.pi/2)
        }
        self.rotationAngle = rotation
    }
    
    open func resetCropRect() {
        resetCropRectAnimated(false)
    }
    
    open func resetCropRectAnimated(_ animated: Bool) {
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.25)
            UIView.setAnimationBeginsFromCurrentState(true)
        }
        imageView?.transform = CGAffineTransform.identity
        let contentSize = scrollView.contentSize
        let initialRect = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
        scrollView.zoom(to: initialRect, animated: false)
        
        layoutCropRectViewWithCropRect(scrollView.bounds)
        
        if animated {
            UIView.commitAnimations()
        }
    }
    
    open func zoomedCropRect() -> CGRect {
        let cropRect = convert(scrollView.frame, to: zoomingView)
        var ratio: CGFloat = 1.0
        let orientation = UIApplication.shared.statusBarOrientation
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad || orientation.isPortrait) {
            ratio = AVMakeRect(aspectRatio: imageSize, insideRect: insetRect).width / imageSize.width
        } else {
            ratio = AVMakeRect(aspectRatio: imageSize, insideRect: insetRect).height / imageSize.height
        }
        
        let zoomedCropRect = CGRect(x: cropRect.origin.x / ratio,
            y: cropRect.origin.y / ratio,
            width: cropRect.size.width / ratio,
            height: cropRect.size.height / ratio)
        
        return zoomedCropRect
    }
    
    open func croppedImage(_ image: UIImage) -> UIImage {
        imageSize = image.size
        return image.rotatedImageWithTransform(rotation, croppedToRect: zoomedCropRect())
    }
    
    @objc func handleRotation(_ gestureRecognizer: UIRotationGestureRecognizer) {
        if let imageView = imageView {
            let rotation = gestureRecognizer.rotation
            let transform = imageView.transform.rotated(by: rotation)
            imageView.transform = transform
            gestureRecognizer.rotation = 0.0
        }
        
        switch gestureRecognizer.state {
        case .began, .changed:
            cropRectView.showsGridMinor = true
        default:
            cropRectView.showsGridMinor = false
        }
    }
    
    // MARK: - Private methods
    fileprivate func showOverlayView(_ show: Bool) {
        let color = show ? UIColor(white: 0.0, alpha: 0.4) : UIColor.clear
        
        topOverlayView.backgroundColor = color
        leftOverlayView.backgroundColor = color
        rightOverlayView.backgroundColor = color
        bottomOverlayView.backgroundColor = color
    }
    
    fileprivate func setupEditingRect() {
        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        if interfaceOrientation.isPortrait {
            editingRect = bounds.insetBy(dx: MarginLeft, dy: MarginTop)
        } else {
            editingRect = bounds.insetBy(dx: MarginLeft, dy: MarginLeft)
        }
        if !showCroppedArea {
            editingRect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
    }
    
    fileprivate func setupZoomingView() {
        let cropRect = AVMakeRect(aspectRatio: imageSize, insideRect: insetRect)
        
        scrollView.frame = cropRect
        scrollView.contentSize = cropRect.size
        
        zoomingView = UIView(frame: scrollView.bounds)
        zoomingView?.backgroundColor = .clear
        scrollView.addSubview(zoomingView!)
    }

    fileprivate func setupImageView() {
        let imageView = UIImageView(frame: zoomingView!.bounds)
        imageView.backgroundColor = .clear
        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        zoomingView?.addSubview(imageView)
        self.imageView = imageView
        usingCustomImageView = false
    }
    
    fileprivate func layoutCropRectViewWithCropRect(_ cropRect: CGRect) {
        cropRectView.frame = cropRect
        layoutOverlayViewsWithCropRect(cropRect)
    }
    
    fileprivate func layoutOverlayViewsWithCropRect(_ cropRect: CGRect) {
        topOverlayView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: cropRect.minY)
        leftOverlayView.frame = CGRect(x: 0, y: cropRect.minY, width: cropRect.minX, height: cropRect.height)
        rightOverlayView.frame = CGRect(x: cropRect.maxX, y: cropRect.minY, width: bounds.width - cropRect.maxX, height: cropRect.height)
        bottomOverlayView.frame = CGRect(x: 0, y: cropRect.maxY, width: bounds.width, height: bounds.height - cropRect.maxY)
    }
    
    fileprivate func zoomToCropRect(_ toRect: CGRect) {
        zoomToCropRect(toRect, shouldCenter: false, animated: true)
    }
    
    fileprivate func zoomToCropRect(_ toRect: CGRect, shouldCenter: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        if scrollView.frame.equalTo(toRect) {
            return
        }
        
        let width = toRect.width
        let height = toRect.height
        let scale = min(editingRect.width / width, editingRect.height / height)
        
        let scaledWidth = width * scale
        let scaledHeight = height * scale
        let cropRect = CGRect(x: (bounds.width - scaledWidth) / 2.0, y: (bounds.height - scaledHeight) / 2.0, width: scaledWidth, height: scaledHeight)
        
        var zoomRect = convert(toRect, to: zoomingView)
        zoomRect.size.width = cropRect.width / (scrollView.zoomScale * scale)
        zoomRect.size.height = cropRect.height / (scrollView.zoomScale * scale)
        
        if let imgView = imageView , shouldCenter {
            let imageViewBounds = imgView.bounds
            zoomRect.origin.x = (imageViewBounds.width / 2.0) - (zoomRect.width / 2.0)
            zoomRect.origin.y = (imageViewBounds.height / 2.0) - (zoomRect.height / 2.0)
        }
        
        var duration = 0.0
        if animated {
            duration = 0.25
        }
        
        UIView.animate(withDuration: duration, delay: 0.0, options: .beginFromCurrentState, animations: { [unowned self] in
            self.scrollView.bounds = cropRect
            self.scrollView.zoom(to: zoomRect, animated: false)
            self.layoutCropRectViewWithCropRect(cropRect)
        }) { finished in
            completion?()
        }
    }
    
    fileprivate func cappedCropRectInImageRectWithCropRectView(_ cropRectView: CropRectView) -> CGRect {
        var cropRect = cropRectView.frame
        
        let rect = convert(cropRect, to: scrollView)
        if rect.minX < zoomingView!.frame.minX {
            cropRect.origin.x = scrollView.convert(zoomingView!.frame, to: self).minX
            let cappedWidth = rect.maxX
            let height = !keepAspectRatio ? cropRect.size.height : cropRect.size.height * (cappedWidth / cropRect.size.width)
            cropRect.size = CGSize(width: cappedWidth, height: height)
        }
        
        if rect.minY < zoomingView!.frame.minY {
            cropRect.origin.y = scrollView.convert(zoomingView!.frame, to: self).minY
            let cappedHeight = rect.maxY
            let width = !keepAspectRatio ? cropRect.size.width : cropRect.size.width * (cappedHeight / cropRect.size.height)
            cropRect.size = CGSize(width: width, height: cappedHeight)
        }
        
        if rect.maxX > zoomingView!.frame.maxX {
            let cappedWidth = scrollView.convert(zoomingView!.frame, to: self).maxX - cropRect.minX
            let height = !keepAspectRatio ? cropRect.size.height : cropRect.size.height * (cappedWidth / cropRect.size.width)
            cropRect.size = CGSize(width: cappedWidth, height: height)
        }
        
        if rect.maxY > zoomingView!.frame.maxY {
            let cappedHeight = scrollView.convert(zoomingView!.frame, to: self).maxY - cropRect.minY
            let width = !keepAspectRatio ? cropRect.size.width : cropRect.size.width * (cappedHeight / cropRect.size.height)
            cropRect.size = CGSize(width: width, height: cappedHeight)
        }
        
        return cropRect
    }
    
    fileprivate func automaticZoomIfEdgeTouched(_ cropRect: CGRect) {
        if cropRect.minX < editingRect.minX - 5.0 ||
            cropRect.maxX > editingRect.maxX + 5.0 ||
            cropRect.minY < editingRect.minY - 5.0 ||
            cropRect.maxY > editingRect.maxY + 5.0 {
                UIView.animate(withDuration: 1.0, delay: 0.0, options: .beginFromCurrentState, animations: { [unowned self] in
                    self.zoomToCropRect(self.cropRectView.frame)
                    }, completion: nil)
        }
    }
    
    fileprivate func setCropAspectRatio(_ ratio: CGFloat, shouldCenter: Bool) {
        var cropRect = scrollView.frame
        var width = cropRect.width
        var height = cropRect.height
        if ratio <= 1.0 {
            width = height * ratio
            if width > imageView!.bounds.width {
                width = cropRect.width
                height = width / ratio
            }
        } else {
            height = width / ratio
            if height > imageView!.bounds.height {
                height = cropRect.height
                width = height * ratio
            }
        }
        cropRect.size = CGSize(width: width, height: height)
        zoomToCropRect(cropRect, shouldCenter: shouldCenter, animated: false) {
            let scale = self.scrollView.zoomScale
            self.scrollView.minimumZoomScale = scale
        }
    }
    
    // MARK: - CropView delegate methods
    func cropRectViewDidBeginEditing(_ view: CropRectView) {
        resizing = true
    }
    
    func cropRectViewDidChange(_ view: CropRectView) {
        let cropRect = cappedCropRectInImageRectWithCropRectView(view)
        layoutCropRectViewWithCropRect(cropRect)
        automaticZoomIfEdgeTouched(cropRect)
    }
    
    func cropRectViewDidEndEditing(_ view: CropRectView) {
        resizing = false
        zoomToCropRect(cropRectView.frame)
    }
    
    // MARK: - ScrollView delegate methods
    open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return zoomingView
    }
    
    open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let contentOffset = scrollView.contentOffset
        targetContentOffset.pointee = contentOffset
    }
    
    // MARK: - Gesture Recognizer delegate methods
    open func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
