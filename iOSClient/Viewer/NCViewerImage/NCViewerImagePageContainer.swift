

import UIKit

protocol NCViewerImagePageContainerDelegate: class {
    func containerViewController(_ containerViewController: NCViewerImagePageContainer, indexDidUpdate currentIndex: Int)
}

class NCViewerImagePageContainer: UIViewController, UIGestureRecognizerDelegate {

    enum ScreenMode {
        case full, normal
    }
    var currentMode: ScreenMode = .normal
    
    weak var delegate: NCViewerImagePageContainerDelegate?
    
    var pageViewController: UIPageViewController {
        return self.children[0] as! UIPageViewController
    }
    
    var currentViewController: NCViewerImageZoom {
        return self.pageViewController.viewControllers![0] as! NCViewerImageZoom
    }
    
    var metadatas: [tableMetadata] = []
    var currentIndex = 0
    var nextIndex: Int?
    
    var panGestureRecognizer: UIPanGestureRecognizer!
    var singleTapGestureRecognizer: UITapGestureRecognizer!
    
    var transitionController = ZoomTransitionController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pageViewController.delegate = self
        pageViewController.dataSource = self
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPanWith(gestureRecognizer:)))
        panGestureRecognizer.delegate = self
        pageViewController.view.addGestureRecognizer(self.panGestureRecognizer)
        
        singleTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didSingleTapWith(gestureRecognizer:)))
        pageViewController.view.addGestureRecognizer(self.singleTapGestureRecognizer)
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        viewerImageZoom.delegate = self
        viewerImageZoom.index = currentIndex
        viewerImageZoom.image = getImageFromMetadata(metadatas[currentIndex])
        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        
        pageViewController.setViewControllers([viewerImageZoom], direction: .forward, animated: true, completion: nil)
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
        switch gestureRecognizer.state {
        case .began:
            currentViewController.scrollView.isScrollEnabled = false
            transitionController.isInteractive = true
            navigationController?.popViewController(animated: true)
        case .ended:
            if transitionController.isInteractive {
                currentViewController.scrollView.isScrollEnabled = true
                transitionController.isInteractive = false
                transitionController.didPanWith(gestureRecognizer: gestureRecognizer)
            }
        default:
            if transitionController.isInteractive {
                transitionController.didPanWith(gestureRecognizer: gestureRecognizer)
            }
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
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.view.backgroundColor = .black
                            
            }, completion: { completed in
            })
        } else {
            navigationController?.setNavigationBarHidden(false, animated: false)
            UIView.animate(withDuration: 0.25,
                           animations: {
                            if #available(iOS 13.0, *) {
                                self.view.backgroundColor = .systemBackground
                            } else {
                                self.view.backgroundColor = .white
                            }
            }, completion: { completed in
            })
        }
    }
    
    func getImageFromMetadata(_ metadata: tableMetadata) -> UIImage {
        if FileManager().fileExists(atPath: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)) {
            return UIImage(contentsOfFile: CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag))!
        } else {
            return NCCollectionCommon.images.cellFileImage
        }
    }
}

extension NCViewerImagePageContainer: UIPageViewControllerDelegate, UIPageViewControllerDataSource {
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        
        if currentIndex == 0 {
            return nil
        }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        viewerImageZoom.delegate = self
        viewerImageZoom.image = getImageFromMetadata(metadatas[currentIndex - 1])
        viewerImageZoom.index = currentIndex - 1
        self.singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        return viewerImageZoom
        
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        
        if currentIndex == (self.metadatas.count - 1) {
            return nil
        }
        
        let viewerImageZoom = UIStoryboard(name: "NCViewerImage", bundle: nil).instantiateViewController(withIdentifier: "NCViewerImageZoom") as! NCViewerImageZoom
        viewerImageZoom.delegate = self
        singleTapGestureRecognizer.require(toFail: viewerImageZoom.doubleTapGestureRecognizer)
        viewerImageZoom.image = getImageFromMetadata(metadatas[currentIndex + 1])
        viewerImageZoom.index = currentIndex + 1
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
            delegate?.containerViewController(self, indexDidUpdate: currentIndex)
        }
        
        self.nextIndex = nil
    }
    
}

extension NCViewerImagePageContainer: NCViewerImageZoomDelegate {
    
    func viewerImageZoom(_ viewerImageZoom: NCViewerImageZoom, scrollViewDidScroll scrollView: UIScrollView) {
        if scrollView.zoomScale != scrollView.minimumZoomScale && currentMode != .full {
            changeScreenMode(to: .full)
            currentMode = .full
        }
    }
}

extension NCViewerImagePageContainer: ZoomAnimatorDelegate {
    
    func transitionWillStartWith(zoomAnimator: ZoomAnimator) {
    }
    
    func transitionDidEndWith(zoomAnimator: ZoomAnimator) {
    }
    
    func referenceImageView(for zoomAnimator: ZoomAnimator) -> UIImageView? {
        return self.currentViewController.imageView
    }
    
    func referenceImageViewFrameInTransitioningView(for zoomAnimator: ZoomAnimator) -> CGRect? {        
        return currentViewController.scrollView.convert(currentViewController.imageView.frame, to: currentViewController.view)
    }
}
