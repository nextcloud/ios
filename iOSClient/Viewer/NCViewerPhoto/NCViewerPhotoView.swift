import UIKit

class NCViewerPhotoView: UIScrollView, UIScrollViewDelegate {
	
	let pagePadding: CGFloat = 10
	var recycledPages: Set<NCViewerPhotoImageScrollView> = []
	var visiblePages: Set<NCViewerPhotoImageScrollView> = []
	var firstVisiblePageIndexBeforeRotation: Int!
	var singleTap: UITapGestureRecognizer!
	var inTilingProcess: Set<String> = []
	var currentImageName: String = ""
    
    var metadata = tableMetadata()
    var metadatas = [tableMetadata]()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(self.changeTheming), name: NSNotification.Name(rawValue: "changeTheming"), object: nil)
    }
    
    @objc func setup(metadata: tableMetadata, view: UIView) {
        
        self.metadata = metadata
        if let metadatas = NCManageDatabase.sharedInstance.getMetadatas(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@ AND typeFile == %@", metadata.account, metadata.serverUrl, k_metadataTypeFile_image), sorted: "fileName", ascending: true) {
            self.metadatas = metadatas
        }
        
        // single tap to show or hide navigation bar
        singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        addGestureRecognizer(self.singleTap)
        
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        isPagingEnabled = true
        contentSize = self.contentSizeForPagingScrollView()
        delegate = self
        view.addSubview(self)
        
        tilePages()
    }
   
    @objc func changeTheming() {
        backgroundColor = NCBrandColor.sharedInstance.backgroundView
    }
    
	//MARK: - Tiling and page configuration
	
	func tilePages() {
		// Calculate which pages should now be visible
		let visibleBounds = self.bounds
		
		var firstNeededPageIndex: Int = Int(floor(visibleBounds.minX/visibleBounds.width))
		var lastNeededPageIndex: Int = Int(floor((visibleBounds.maxX - 1)/visibleBounds.width))
		firstNeededPageIndex = max(firstNeededPageIndex, 0)
        lastNeededPageIndex = min(lastNeededPageIndex, metadatas.count - 1)
		
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
				self.addSubview(page)
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
		page.backgroundColor = self.backgroundColor

		page.index = index
		page.frame = self.frameForPage(at: index)
		self.displayImage(at: index, in: page)
	}
	
	func displayImage(at index: Int, in page: NCViewerPhotoImageScrollView) {
        let metadata = metadatas[index]
        if CCUtility.fileProviderStorageExists(metadata.ocId, fileNameView: metadata.fileNameView) == false {
            return
        }
        let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadatas[index].ocId, fileNameView: metadatas[index].fileNameView)!
		let tileManager = NCViewerPhotoTileManager()

		if !tileManager.needsTilingImage(in: URL(fileURLWithPath: imagePath)) {
			let image: UIImage! = UIImage(contentsOfFile: imagePath)
			page.display(image)
			return
		}

        /*
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
        */
	}
	
	//MARK: - ScrollView delegate methods
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		self.tilePages()
	}
	
	//MARK: - Frame calculations
	
	func frameForPagingScrollView(in size: CGSize? = nil) -> CGRect {
        var frame = self.bounds
		
		if size != nil {
			frame.size = size!
		}
		
		frame.origin.x -= pagePadding
		frame.size.width += 2*pagePadding
		return frame
	}
	
	func contentSizeForPagingScrollView() -> CGSize {
		let bounds = self.bounds
        return CGSize(width: bounds.size.width*CGFloat(metadatas.count), height: bounds.size.height)
	}
	
	func frameForPage(at index: Int) -> CGRect {
		
		let bounds = self.bounds
		var pageFrame = bounds
		pageFrame.size.width -= 2*pagePadding
		pageFrame.origin.x = (bounds.size.width*CGFloat(index)) + pagePadding
		
		return pageFrame
	}
	
	func saveCurrentStatesForRotation() {
        let visibleBounds = self.bounds
		firstVisiblePageIndexBeforeRotation = Int(floor(visibleBounds.minX/visibleBounds.width))
	}
	
	func restoreStatesForRotation(in size: CGSize) {
		// recalculate contentSize based on current orientation
		let pagingScrollViewFrame = self.frameForPagingScrollView(in: size)
		self.frame = pagingScrollViewFrame
		self.contentSize = self.contentSizeForPagingScrollView()
		
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
		
		let pageWidth = self.bounds.size.width
		contentOffset.x = (CGFloat(firstVisiblePageIndexBeforeRotation) * pageWidth)
		
		self.contentOffset = contentOffset
		
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
}
