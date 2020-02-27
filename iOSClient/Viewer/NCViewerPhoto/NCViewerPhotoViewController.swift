import UIKit

class NCViewerPhotoViewController: UIViewController, UIScrollViewDelegate {
	
	let pagePadding: CGFloat = 10
	var pagingScrollView: UIScrollView!
	var recycledPages: Set<NCViewerPhotoImageScrollView> = []
	var visiblePages: Set<NCViewerPhotoImageScrollView> = []
	var firstVisiblePageIndexBeforeRotation: Int!
	var singleTap: UITapGestureRecognizer!
	var inTilingProcess: Set<String> = []
	var currentImageName: String = ""
    
    var metadata: tableMetadata?

	override func viewDidLoad() {
		super.viewDidLoad()
		
		// single tap to show or hide navigation bar
		self.singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
		self.view.addGestureRecognizer(self.singleTap)
		
		self.pagingScrollView = UIScrollView(frame: self.frameForPagingScrollView())
		//self.updateBackgroundColor()
		self.pagingScrollView.showsVerticalScrollIndicator = false
		self.pagingScrollView.showsHorizontalScrollIndicator = false
		self.pagingScrollView.isPagingEnabled = true
		self.pagingScrollView.contentSize = self.contentSizeForPagingScrollView()
		self.pagingScrollView.delegate = self
        if #available(iOS 11.0, *) {
            pagingScrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
		self.view.addSubview(self.pagingScrollView)
		self.layoutPagingScrollView()
		
		self.tilePages()
	}
	
	//MARK: - Tiling and page configuration
	
	func tilePages() {
		// Calculate which pages should now be visible
		let visibleBounds = pagingScrollView.bounds
		
		var firstNeededPageIndex: Int = Int(floor(visibleBounds.minX/visibleBounds.width))
		var lastNeededPageIndex: Int = Int(floor((visibleBounds.maxX - 1)/visibleBounds.width))
		firstNeededPageIndex = max(firstNeededPageIndex, 0)
		lastNeededPageIndex = min(lastNeededPageIndex, self.imageCount - 1)
		
		//Recycle no longer needs pages
		for page in self.visiblePages {
			if page.index < firstNeededPageIndex || page.index > lastNeededPageIndex {
				self.recycledPages.insert(page)
				page.removeFromSuperview()
			}
		}
		self.visiblePages.subtract(self.recycledPages)
		
		//add missing pages
		for index in firstNeededPageIndex...lastNeededPageIndex {
			if !self.isDisplayingPage(forIndex: index) {
				let page = self.dequeueRecycledPage() ?? NCViewerPhotoImageScrollView()
				
				self.configure(page, for: index)
				self.pagingScrollView.addSubview(page)
				self.visiblePages.insert(page)
				
			}
		}
		
	}
	
	func dequeueRecycledPage() -> NCViewerPhotoImageScrollView? {
		if let page = self.recycledPages.first {
			self.recycledPages.removeFirst()
			return page
		}
		return nil
	}
	
	
	func isDisplayingPage(forIndex index: Int) -> Bool {
		for page in self.visiblePages {
			if page.index == index {
				return true
			}
		}
		return false
	}
	
	
	func configure(_ page: NCViewerPhotoImageScrollView, for index: Int) {
		self.singleTap.require(toFail: page.zoomingTap)
		page.backgroundColor = self.view.backgroundColor

		page.index = index
		page.frame = self.frameForPage(at: index)
		self.displayImage(at: index, in: page)
	}
	
	func displayImage(at index: Int, in page: NCViewerPhotoImageScrollView) {
		let imageFileName = self.imageName(at: index)
		self.currentImageName = imageFileName
		let imageURL = Bundle.main.url(forResource: imageFileName, withExtension: "jpg")!
		
		let tileManager = NCViewerPhotoTileManager()

		if !tileManager.needsTilingImage(in: imageURL) {
			let image: UIImage! = UIImage(contentsOfFile: imageURL.path)
			page.display(image)
			return
		}

		if tileManager.tilesMadeForImage(named: imageFileName) {
			let size = tileManager.sizeOfTiledImage(named: imageFileName)!
			let url = tileManager.urlOfTiledImage(named: imageFileName)
			page.displayTiledImage(in: url, size: size)
		}
		else {
			
			if self.inTilingProcess.contains(imageFileName) {
				if let placeholderURL = tileManager.urlOfPlaceholderOfImage(named: imageFileName) {
					let image: UIImage! = UIImage(contentsOfFile: placeholderURL.path)
					page.display(image)
				}
				return
			}
			else {
				self.inTilingProcess.insert(imageFileName)
			}

			tileManager.makeTiledImage(for: imageURL, placeholderCompletion: { (url, error) in
				if error == nil {
					let image: UIImage! = UIImage(contentsOfFile: url!.path)
					page.display(image)
				}
				
			}, tilingCompletion: { (imageName, imageSize, error) in
				if error == nil, imageName == self.currentImageName {
					let url = tileManager.urlOfTiledImage(named: imageName!)
					page.displayTiledImage(in: url, size: imageSize!)
					
					if self.inTilingProcess.contains(imageName!) {
						self.inTilingProcess.remove(imageName!)
					}
					
				}
				else {
					if error != nil {
						print(error!)
					}
				}
			})
			
		}
		
	}
	
	//MARK: - ScrollView delegate methods
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		self.tilePages()
	}
	
	//MARK: - Frame calculations
	
	func frameForPagingScrollView(in size: CGSize? = nil) -> CGRect {
		var frame = UIScreen.main.bounds
		
		if size != nil {
			frame.size = size!
		}
		
		frame.origin.x -= pagePadding
		frame.size.width += 2*pagePadding
		return frame
	}
	
	func contentSizeForPagingScrollView() -> CGSize {
		let bounds = self.pagingScrollView.bounds
		return CGSize(width: bounds.size.width*CGFloat(self.imageCount), height: bounds.size.height)
	}
	
	func frameForPage(at index: Int) -> CGRect {
		
		let bounds = self.pagingScrollView.bounds
		var pageFrame = bounds
		pageFrame.size.width -= 2*pagePadding
		pageFrame.origin.x = (bounds.size.width*CGFloat(index)) + pagePadding
		
		return pageFrame
	}
	
	//MARK: - Rotation Configuration
	
	override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
		self.saveCurrentStatesForRotation()
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		self.restoreStatesForRotation(in: size)
	}
	
	/**
	Save current page and zooming states for device rotation.
	*/
	func saveCurrentStatesForRotation() {
		let visibleBounds = pagingScrollView.bounds
		firstVisiblePageIndexBeforeRotation = Int(floor(visibleBounds.minX/visibleBounds.width))
	}
	
	/**
	Apply tracked informations for device rotation.
	*/
	func restoreStatesForRotation(in size: CGSize) {
		// recalculate contentSize based on current orientation
		let pagingScrollViewFrame = self.frameForPagingScrollView(in: size)
		pagingScrollView?.frame = pagingScrollViewFrame
		pagingScrollView?.contentSize = self.contentSizeForPagingScrollView()
		
		// adjust frames and configuration of each visible page
		for page in visiblePages {
			let restorePoint = page.pointToCenterAfterRotation()
			let restoreScale = page.scaleToRestoreAfterRotation()
			page.frame = self.frameForPage(at: page.index)
			page.setMaxMinZoomScaleForCurrentBounds()
			page.restoreCenterPoint(to: restorePoint, oldScale: restoreScale)
		}
		
		// adjust contentOffset to preserve page location based on values collected prior to location
		var contentOffset = CGPoint.zero
		
		let pageWidth = pagingScrollView?.bounds.size.width ?? 1
		contentOffset.x = (CGFloat(firstVisiblePageIndexBeforeRotation) * pageWidth)
		
		pagingScrollView?.contentOffset = contentOffset
		
	}
	
	//MARK: - Handle Tap
	
	/// Single tap action which hides navigationBar by default implementation
	@objc func handleSingleTap() {
        /*
        let duration: TimeInterval = 0.2
         
		if self.navigationController != nil {
			
			if !self.navigationBarIsHidden {
				
				self.navigationBarIsHidden = true
				UIView.animate(withDuration: duration, animations: {
					self.navigationController!.navigationBar.alpha = 0
					self.updateBackgroundColor()

				}, completion: { (finished) in
					self.navigationController!.navigationBar.isHidden = true
				})
				
			}
			else {
				self.navigationBarIsHidden = false
				UIView.animate(withDuration: duration) {
					self.navigationController!.navigationBar.alpha = 1
					self.navigationController!.navigationBar.isHidden = false
					self.updateBackgroundColor()
				}
			}
		}
        */
	}
    
	/// Update background color. Default is white / black.
    /*
	func updateBackgroundColor() {
		if  !self.navigationBarIsHidden {
			self.updateBackground(to: .white)
		}
		else {
			self.updateBackground(to: .black)
		}
	}
	*/
    
    /*
	func updateBackground(to color: UIColor) {
		self.view.backgroundColor = color
		pagingScrollView?.backgroundColor = color
		
		for page in visiblePages {
			page.backgroundColor = color
		}
	}
	*/
    
	func layoutPagingScrollView() {
		self.pagingScrollView.translatesAutoresizingMaskIntoConstraints = false
		
		let top = NSLayoutConstraint(item: self.pagingScrollView!, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .top, multiplier: 1.0, constant: 0.0)
		let left = NSLayoutConstraint(item: self.pagingScrollView!, attribute: .left, relatedBy: .equal, toItem: self.view, attribute: .left, multiplier: 1.0, constant: -10.0)
		
		let bottom = NSLayoutConstraint(item: self.pagingScrollView!, attribute: .bottom, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: 0.0)
		let right = NSLayoutConstraint(item: self.pagingScrollView!, attribute: .right, relatedBy: .equal, toItem: self.view, attribute: .right, multiplier: 1.0, constant: 10.0)
		
		self.view.addConstraints([top, left, bottom, right])
	}
	
	//MARK: - Image Fetching tools
	
	lazy var imageData: [Any]? = {
		var data: [Any]? = nil
		
		DispatchQueue.global().sync {
			let path = Bundle.main.url(forResource: "ImageData", withExtension: "plist")
			do {
				let plistData = try Data(contentsOf: path!)
				data = try PropertyListSerialization.propertyList(from: plistData, options: PropertyListSerialization.ReadOptions.mutableContainers, format: nil) as? [Any]
				// return data
			}
			catch {
				print("Unable to read image data: ", error)
			}
			
		}
		return data
	}()
	
	lazy var imageCount: Int = {
		return self.imageData?.count ?? 0
	}()
	
	func imageName(at index: Int) -> String {
		if let info = imageData?[index] as? [String: Any] {
			return info["name"] as? String ?? ""
		}
		return ""
	}
	
	// we use "imageWithContentsOfFile:" instead of "imageNamed:" here to avoid caching
	func image(at index: Int) -> UIImage {
		let name = imageName(at: index)
		if let path = Bundle.main.path(forResource: name, ofType: "jpg") {
			return UIImage(contentsOfFile: path)!
		}
		return UIImage()
	}
	
	func imageSizeAt(index: Int) -> CGSize {
		if let info = imageData?[index] as? [String: Any] {
			return CGSize(width: info["width"] as? CGFloat ?? 0, height: info["height"] as? CGFloat ?? 0)
		}
		return CGSize.zero
	}
	
}
