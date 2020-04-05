//
//  FastScrollCollectionView.swift
//  FastScroll
//
//  Created by Arsene Huot on 15/06/2018.
//  Copyright © 2018 Frichti. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol FastScrollCollectionViewDelegate {
    @objc func hideHandle()
}

open class FastScrollCollectionView: UICollectionView {
    public enum BubbleFocus {
        case first
        case last
        case dynamic
    }
    
    // Bubble to display your information during scroll
    public var deactivateBubble: Bool = false
    public var bubble: UITextView?
    public var bubbleFont: UIFont =  UIFont.systemFont(ofSize: 12.0)
    public var bubbleTextSize: CGFloat = 12.0
    public var bubbleTextColor: UIColor = UIColor.white
    public var bubbleRadius: CGFloat = 20.0
    public var bubblePadding: CGFloat = 12.0
    public var bubbleMarginRight: CGFloat = 30.0
    public var bubbleColor: UIColor = UIColor.darkGray
    public var bubbleShadowColor: UIColor = UIColor.darkGray
    public var bubbleShadowOpacity: Float = 0.7
    public var bubbleShadowRadius: CGFloat = 3.0
    public var bubbleShadowOffset: CGSize = CGSize(width: 0.0, height: 5.0)
    public var bubbleFocus: BubbleFocus = .first
    
    // Handler to scroll
    public var handle: UIView?
    public var handleImage: UIImage?
    public var handleWidth: CGFloat = 30.0
    public var handleHeight: CGFloat = 30.0
    public var handleRadius: CGFloat = 15.0
    public var handleMarginRight: CGFloat = 6.0
    public var handleShadowColor: UIColor = UIColor.darkGray
    public var handleShadowOpacity: Float = 0.7
    public var handleShadowOffset: CGSize = CGSize(width: 0.0, height: 5.0)
    public var handleShadowRadius: CGFloat = 3.0
    public var handleColor: UIColor = UIColor.darkGray
    public var handleTimeToDisappear: CGFloat = 1.5
    public var handleDisappearAnimationDuration: CGFloat = 0.2
    fileprivate var handleTouched: Bool = false
    
    // Gesture center on handler
    public var gestureHandleView: UIView?
    public var gestureWidth: CGFloat = 50.0
    public var gestureHeight: CGFloat = 50.0
    
    // Scrollbar
    public var scrollbar: UIView?
    public var scrollbarWidth: CGFloat = 2.0
    public var scrollbarColor: UIColor = UIColor(red: 220.0 / 255.0, green: 220.0 / 255.0, blue: 220.0 / 255.0, alpha: 1.0)
    public var scrollbarRadius: CGFloat = 1.0
    public var scrollbarMarginTop: CGFloat = 40.0
    public var scrollbarMarginBottom: CGFloat = 20.0
    public var scrollbarMarginRight: CGFloat = 20.0
    
    // Timer to dismiss handle
    fileprivate var handleTimer: Timer?
    
    // Action callback
    public var bubbleNameForIndexPath: (IndexPath) -> String = { _ in return ""}
    
    // Delegate
    public var fastScrollDelegate: FastScrollCollectionViewDelegate?
    
    // MARK: LifeCycle
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        setup()
        setupCollectionView()
    }
    
    // MARK: Setups
    
    fileprivate func setupCollectionView() {
        showsVerticalScrollIndicator = false
    }
    
    public func setup() {
        cleanViews()
        
        setupScrollbar()
        setupHandle()
        setupBubble()
    }
    
    public func cleanViews() {
        guard let bubble = bubble, let handle = handle, let scrollbar = scrollbar, let gestureHandleView = gestureHandleView else {
            return
        }
        
        bubble.removeFromSuperview()
        handle.removeFromSuperview()
        scrollbar.removeFromSuperview()
        gestureHandleView.removeFromSuperview()
        
        self.bubble = nil
        self.handle = nil
        self.scrollbar = nil
        self.gestureHandleView = nil
    }
    
    fileprivate func setupHandle() {
        if handle == nil {
            handle = UIView(frame: CGRect(x: self.frame.width - handleWidth - handleMarginRight, y: scrollbarMarginTop, width: handleWidth, height: handleHeight))
            self.superview?.addSubview(handle!)
            
            gestureHandleView  = UIView(frame: CGRect(x: 0.0, y: 0.0, width: gestureWidth, height: gestureHeight))
            gestureHandleView!.center = handle!.center
            
            self.superview?.addSubview(handle!)
            self.superview?.addSubview(gestureHandleView!)
        }
        
        //config layer
        handle!.backgroundColor = handleColor
        handle!.layer.cornerRadius = handleRadius
        handle!.layer.shadowColor = handleShadowColor.cgColor
        handle!.layer.shadowOffset = handleShadowOffset
        handle!.layer.shadowRadius = handleShadowRadius
        handle!.layer.shadowOpacity = handleShadowOpacity
        
        //set imageView
        if let handleImage = handleImage {
            let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: handleWidth, height: handleHeight))
            imageView.image = handleImage
            handle!.addSubview(imageView)
        }
        
        //set gesture
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        gestureHandleView!.addGestureRecognizer(panGesture)
        
        //hide
        handle!.alpha = 0.0
        handle!.isHidden = true
        gestureHandleView!.isHidden = true
        
        //position
        positionHandle(scrollbarMarginTop)
    }
    
    fileprivate func setupBubble() {
        if bubble == nil {
            bubble = UITextView()
            self.superview?.addSubview(bubble!)
        }
        
        bubble!.font = bubbleFont
        bubble!.font = UIFont(name: bubbleFont.fontName, size: bubbleTextSize)
        bubble!.text = "Test"
        bubble!.textColor = bubbleTextColor
        bubble!.textAlignment = NSTextAlignment.center
        bubble!.textContainerInset = UIEdgeInsets(top: bubblePadding, left: bubblePadding, bottom: bubblePadding, right: bubblePadding)
        bubble!.contentMode = UIView.ContentMode.scaleAspectFit
        bubble!.sizeToFit()
        
        bubble!.backgroundColor = bubbleColor
        bubble!.layer.cornerRadius = bubbleRadius
        bubble!.layer.shadowColor = bubbleShadowColor.cgColor
        bubble!.layer.shadowOffset = bubbleShadowOffset
        bubble!.layer.shadowRadius = bubbleRadius
        bubble!.layer.shadowOpacity = bubbleShadowOpacity
        bubble!.layer.shadowRadius = bubbleShadowRadius
        bubble!.layer.masksToBounds = false
        
        bubble!.isHidden = true
        
        updateBubblePosition()
    }
    
    fileprivate func setupScrollbar() {
        guard let superview = self.superview else {
            return
        }
        
        if scrollbar == nil {
            scrollbar = UIView(frame: CGRect(x: self.frame.width - scrollbarWidth - scrollbarMarginRight, y: scrollbarMarginTop, width: scrollbarWidth, height: superview.bounds.height - scrollbarMarginBottom - scrollbarMarginTop))
            self.superview?.addSubview(scrollbar!)
        }
        
        scrollbar!.backgroundColor = scrollbarColor
        scrollbar!.layer.cornerRadius = scrollbarRadius
        scrollbar!.alpha = 0.0
        scrollbar!.isHidden = true
    }
    
    // MARK: Helpers
    @objc func hideHandle() {
        guard let handle = handle, let scrollbar = scrollbar, let gestureHandleView = gestureHandleView else {
            return
        }
        
        if gestureHandleView.isHidden == false {
            self.fastScrollDelegate?.hideHandle()
        }
        
        gestureHandleView.isHidden = true
        
        UIView.animate(withDuration: TimeInterval(handleDisappearAnimationDuration), animations: {
            handle.alpha = 0.0
            scrollbar.alpha = 0.0
        }, completion: { finished in
            if finished {
                handle.isHidden = true
                scrollbar.isHidden = true
            }
        })
    }
    
    fileprivate func updateBubblePosition() {
        guard let scrollbar = scrollbar, let bubble = bubble, let handle = handle else {
            return
        }
        
        bubble.frame.origin.x = scrollbar.frame.origin.x - bubble.frame.size.width - bubbleMarginRight
        bubble.center.y = handle.center.y
    }
    
    fileprivate func positionHandle(_ y: CGFloat) {
        guard let handle = handle, let scrollbar = scrollbar, let gestureHandleView = gestureHandleView else {
            return
        }
        
        handle.frame.origin.y = y >= scrollbarMarginTop ?
            (y > scrollbarMarginTop + scrollbar.frame.height - handle.frame.height) ? scrollbarMarginTop + scrollbar.frame.height - handle.frame.height : y
            :
        scrollbarMarginTop
        
        gestureHandleView.center = handle.center
    }
    
    fileprivate func scrollCollectionFromHandle() {
        guard let handle = handle, let scrollbar = scrollbar else {
            return
        }
        
        let collectionContentHeight = self.contentSize.height - self.bounds.height
        let scrollBarHeight = scrollbar.frame.height
        
        let scrollY = (handle.frame.origin.y - scrollbarMarginTop) * (collectionContentHeight / (scrollBarHeight - handle.frame.size.height))
        
        self.setContentOffset(CGPoint(x: 0.0, y: scrollY), animated: false)
    }
    
    @objc func handlePanGesture(_ panGesture: UIPanGestureRecognizer) {
        guard let superview = superview, let bubble = bubble, let handle = handle, let scrollbar = scrollbar, let gestureHandleView = gestureHandleView  else {
            return
        }
        
        // get translation
        let translation = panGesture.translation(in: superview)
        panGesture.setTranslation(CGPoint.zero, in: superview)
        
        // manage start stop pan
        if panGesture.state == UIGestureRecognizer.State.began {
            bubble.isHidden = deactivateBubble ? true : false
            handleTouched = true
            
            //invalid hide timer
            if let handleTimer = handleTimer {
                handleTimer.invalidate()
            }
            
            handle.alpha = 1.0
            scrollbar.alpha = 1.0
            handle.isHidden = false
            scrollbar.isHidden = false
            gestureHandleView.isHidden = false
        }
        
        if panGesture.state == UIGestureRecognizer.State.ended {
            bubble.isHidden = true
            handleTouched = false
            if contentOffset.y < 0 {
                self.setContentOffset(CGPoint(x: 0.0, y: 0), animated: false)
            }
            self.handleTimer = Timer.scheduledTimer(timeInterval: TimeInterval(handleTimeToDisappear), target: self, selector: #selector(hideHandle), userInfo: nil, repeats: false)
        }
        
        if panGesture.state == UIGestureRecognizer.State.changed {
            //invalid hide timer
            if let handleTimer = handleTimer {
                handleTimer.invalidate()
            }
            
            handle.alpha = 1.0
            scrollbar.alpha = 1.0
            handle.isHidden = false
            scrollbar.isHidden = false
            gestureHandleView.isHidden = false
        }
        
        // views positions
        positionHandle(handle.frame.origin.y + translation.y)
        updateBubblePosition()
        scrollCollectionFromHandle()
        
        // manage bubble info
        manageBubbleInfo()
    }
    
    fileprivate func manageBubbleInfo() {
        guard let bubble = bubble else {
            return
        }
        
        let visibleCells = self.visibleCells
        
        var currentCellIndex: Int
        
        switch bubbleFocus {
        case .first:
            currentCellIndex = 0
            
        case .last:
            currentCellIndex = visibleCells.count - 1
            
        case .dynamic:
            //Calcul scroll percentage
            let scrollY =  contentOffset.y
            let collectionContentHeight = self.contentSize.height > self.bounds.height ? self.contentSize.height - self.bounds.height : self.bounds.height
            let scrollPercentage = scrollY / collectionContentHeight
            currentCellIndex = Int(floor(CGFloat(visibleCells.count) * scrollPercentage))
            if currentCellIndex < 0 {
                currentCellIndex = 0
            }
        }
        
        if currentCellIndex < visibleCells.count {
            if let indexPath = indexPath(for: visibleCells[currentCellIndex]) {
                bubble.text = bubbleNameForIndexPath(indexPath)
                let newSize = bubble.sizeThatFits(CGSize(width: self.bounds.width - (self.bounds.width - (bubble.frame.origin.x + bubble.frame.size.width)), height: bubble.frame.size.height))
                let oldSize = bubble.frame.size
                bubble.frame = CGRect(x: bubble.frame.origin.x + (oldSize.width - newSize.width), y: bubble.frame.origin.y, width: newSize.width, height: newSize.height)
            }
        }
    }
}

// MARK: Scroll Management

extension FastScrollCollectionView {
    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard let handle = handle, let scrollbar = scrollbar, let gestureHandleView = gestureHandleView else {
            return
        }
        
        handle.alpha = 1.0
        scrollbar.alpha = 1.0
        handle.isHidden = false
        scrollbar.isHidden = false
        gestureHandleView.isHidden = false
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.handleTimer = Timer.scheduledTimer(timeInterval: TimeInterval(handleTimeToDisappear), target: self, selector: #selector(hideHandle), userInfo: nil, repeats: false)
        }
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.handleTimer = Timer.scheduledTimer(timeInterval: TimeInterval(handleTimeToDisappear), target: self, selector: #selector(hideHandle), userInfo: nil, repeats: false)
    }
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let handle = handle, let scrollbar = scrollbar else {
            return
        }
        
        //invalid timer
        if let handleTimer = handleTimer {
            handleTimer.invalidate()
        }
        
        //scroll position
        let scrollY =  scrollView.contentOffset.y
        let collectionContentHeight = self.contentSize.height > self.bounds.height ? self.contentSize.height - self.bounds.height : self.bounds.height
        let scrollBarHeight = scrollbar.frame.height
        
        
        let handlePosition = (scrollY / collectionContentHeight) * (scrollBarHeight - handle.frame.size.height) + scrollbarMarginTop
        if (handleTouched == false) {
            positionHandle(handlePosition)
        }
        
        updateBubblePosition()
    }
}

