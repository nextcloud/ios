//
//  NCViewerImagePageContainer.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 24/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

class NCViewerImagePageContainer: UIViewController, UIGestureRecognizerDelegate {

    enum ScreenMode {
        case full, normal
    }
    var currentMode: ScreenMode = .normal
        
    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }
    
    var currentViewController: NCViewerImageZoom {
        return self.pageViewController.viewControllers![0] as! NCViewerImageZoom
    }
    
    var metadatas: [tableMetadata] = []
    var metadata: tableMetadata = tableMetadata()
    var currentIndex = 0
    var nextIndex: Int?
   
    var startPanLocation = CGPoint.zero
    let panDistanceForPopViewController: CGFloat = 100
    var defaultImageViewTopConstraint: CGFloat = 0
    var defaultImageViewBottomConstraint: CGFloat = 0
    
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanWith(gestureRecognizer:)))

        pageViewController.delegate = self
        pageViewController.dataSource = self
        pageViewController.view.addGestureRecognizer(self.panGestureRecognizer)
        pageViewController.view.addGestureRecognizer(self.singleTapGestureRecognizer)
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        
        viewerImageZoom.index = currentIndex
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex])
        viewerImageZoom.metadata = metadatas[currentIndex]
        viewerImageZoom.delegate = self

        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerImageZoom], direction: .forward, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let buttonMore = UIBarButtonItem.init(image: CCGraphics.changeThemingColorImage(UIImage(named: "more"), width: 50, height: 50, color: NCBrandColor.sharedInstance.textView), style: .plain, target: self, action: #selector(self.openMenuMore))
        navigationItem.rightBarButtonItem = buttonMore
        
        navigationController?.navigationBar.prefersLargeTitles = true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if let gestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = gestureRecognizer.velocity(in: self.view)
            
            var velocityCheck : Bool = false
            
            if UIDevice.current.orientation.isLandscape {
                velocityCheck = velocity.x < 0
            }
            else {
                velocityCheck = velocity.y < 0
            }
            if velocityCheck {
                return false
            }
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        if otherGestureRecognizer == currentViewController.scrollView.panGestureRecognizer {
            if self.currentViewController.scrollView.contentOffset.y == 0 {
                return true
            }
        }
        
        return false
    }

    @objc func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        let currentLocation = gestureRecognizer.translation(in: self.view)

        switch gestureRecognizer.state {
        case .began:
            startPanLocation = currentLocation
            defaultImageViewTopConstraint = currentViewController.imageViewTopConstraint.constant
            defaultImageViewBottomConstraint = currentViewController.imageViewBottomConstraint.constant
            currentViewController.scrollView.isScrollEnabled = false
        case .ended:
            currentViewController.scrollView.isScrollEnabled = true
            currentViewController.imageViewTopConstraint.constant = defaultImageViewTopConstraint
            currentViewController.imageViewBottomConstraint.constant = defaultImageViewBottomConstraint
        case .changed:
            let dy = currentLocation.y - startPanLocation.y
            currentViewController.imageViewTopConstraint.constant = defaultImageViewTopConstraint + dy
            currentViewController.imageViewBottomConstraint.constant = defaultImageViewBottomConstraint - dy
            if dy >= panDistanceForPopViewController {
                self.navigationController?.popViewController(animated: true)
            }
            print(dy)
        default:
            break
        }
    }
    
    @objc func didSingleTapWith(gestureRecognizer: UITapGestureRecognizer) {
        if self.currentMode == .full {
            changeScreenMode(to: .normal)
            self.currentMode = .normal
        } else {
            changeScreenMode(to: .full)
            self.currentMode = .full
        }
    }
    
    func changeScreenMode(to: ScreenMode) {
        if to == .full {
            navigationController?.setNavigationBarHidden(true, animated: false)
            view.backgroundColor = .black
        } else {
            navigationController?.setNavigationBarHidden(false, animated: false)
            view.backgroundColor = NCBrandColor.sharedInstance.backgroundView
        }
    }
    
    func getImageMetadata(_ metadata: tableMetadata) -> UIImage {
                
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            return UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))!
        } else {
            return NCCollectionCommon.images.cellFileImage
        }
    }
    
    @objc func viewUnload() {
        
        navigationController?.popViewController(animated: true)
    }
    
    //MARK: - Action
    
    @objc func openMenuMore() {
        NCViewer.shared.toggleMoreMenu(viewController: self, metadata: metadata)
    }
}

extension NCViewerImagePageContainer: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        if currentIndex == 0 {
            return nil
        }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex - 1])
        viewerImageZoom.index = currentIndex - 1
        viewerImageZoom.metadata = metadatas[currentIndex - 1]
        viewerImageZoom.delegate = self
        
        self.singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        return viewerImageZoom
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        if currentIndex == (self.metadatas.count - 1) {
            return nil
        }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        
        viewerImageZoom.index = currentIndex + 1
        viewerImageZoom.image = getImageMetadata(metadatas[currentIndex + 1])
        viewerImageZoom.metadata = metadatas[currentIndex + 1]
        viewerImageZoom.delegate = self
        
        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)

        return viewerImageZoom
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        
        guard let nextVC = pendingViewControllers.first as? NCViewerImageZoom else {
            return
        }
        
        self.nextIndex = nextVC.index
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        
        if (completed && self.nextIndex != nil) {
            previousViewControllers.forEach { vc in
                let viewerImageZoom = vc as! NCViewerImageZoom
                viewerImageZoom.scrollView.zoomScale = viewerImageZoom.scrollView.minimumZoomScale
            }

            currentIndex = nextIndex!
        }
        
        self.nextIndex = nil
    }
}
