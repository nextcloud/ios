import UIKit

class NCViewerPhotoImageScrollView: UIScrollView, UIScrollViewDelegate {
	
	var index: Int!
	var zoomView: UIImageView!
	var tilingView: NCViewerPhotoTilingView?
	
	lazy var zoomingTap: UITapGestureRecognizer = {
		let zoomingTap = UITapGestureRecognizer(target: self, action: #selector(handleZoomingTap(_:)))
		zoomingTap.numberOfTapsRequired = 2
		
		return zoomingTap
	}()

	override init(frame: CGRect) {
		super.init(frame: frame)
		
		self.showsHorizontalScrollIndicator = false
		self.showsVerticalScrollIndicator = false
        self.decelerationRate = UIScrollView.DecelerationRate.fast
		self.delegate = self
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		self.centerImage()
	}
	
	//MARK: - Configure scrollView to display new image
	func display(_ image: UIImage) {
		
		//1. clear the previous image
		zoomView?.removeFromSuperview()
		zoomView = nil
				
		//2. make a new UIImageView for the new image
		zoomView = UIImageView(image: image)
		
		self.addSubview(zoomView)
		
		self.configureFor(image.size)
	}
	
	func displayTiledImage(in url: URL, size imageSize: CGSize) {
		
		// clear views for the previous image
		zoomView?.removeFromSuperview()
		zoomView = nil
		tilingView = nil
		
		// make views to display the new image
		zoomView = UIImageView(frame: CGRect(origin: CGPoint.zero, size: imageSize))
		let image = placeholderImage(in: url)
		zoomView.image = image
		self.addSubview(zoomView)
		
		self.tilingView = NCViewerPhotoTilingView(in: url, size: imageSize)
		self.zoomView?.addSubview(self.tilingView!)
		
		self.configureFor(imageSize)
	}

	
	func configureFor(_ imageSize: CGSize) {
		self.contentSize = imageSize
		self.setMaxMinZoomScaleForCurrentBounds()
		self.zoomScale = self.minimumZoomScale
		
		//Enable zoom tap
		self.zoomView.addGestureRecognizer(self.zoomingTap)
		self.zoomView.isUserInteractionEnabled = true
	}
	
	func setMaxMinZoomScaleForCurrentBounds() {
		let boundsSize = self.bounds.size
		let imageSize = zoomView.bounds.size
		
		//1. calculate minimumZoomscale
		let xScale =  boundsSize.width  / imageSize.width    // the scale needed to perfectly fit the image width-wise
		let yScale = boundsSize.height / imageSize.height  // the scale needed to perfectly fit the image height-wise
		
		let minScale = min(xScale, yScale)                 // use minimum of these to allow the image to become fully visible
		
		//2. calculate maximumZoomscale
		var maxScale: CGFloat = 1.0
		
		if minScale < 0.1 {
			maxScale = 0.3
		}
		
		if minScale >= 0.1 && minScale < 0.5 {
			maxScale = 0.7
		}
		
		if minScale >= 0.5 {
			maxScale = max(1.0, minScale)
		}
		
		
		self.maximumZoomScale = maxScale
		self.minimumZoomScale = minScale
	}
	
	func centerImage() {
		// center the zoom view as it becomes smaller than the size of the screen
		let boundsSize = self.bounds.size
		var frameToCenter = zoomView?.frame ?? CGRect.zero
		
		// center horizontally
		if frameToCenter.size.width < boundsSize.width {
			frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width)/2
		}
		else {
			frameToCenter.origin.x = 0
		}
		
		// center vertically
		if frameToCenter.size.height < boundsSize.height {
			frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height)/2
		}
		else {
			frameToCenter.origin.y = 0
		}
		
		zoomView?.frame = frameToCenter
	}

	//MARK: - UIScrollView Delegate Methods
	
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return self.zoomView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		self.centerImage()
	}
	
	//MARK: - Methods called during rotation to preserve the zoomScale and the visible portion of the image
	
	// returns the center point, in image coordinate space, to try restore after rotation.
	func pointToCenterAfterRotation() -> CGPoint {
		let boundsCenter = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
		return self.convert(boundsCenter, to: zoomView)
	}
	
	// returns the zoom scale to attempt to restore after rotation.
	func scaleToRestoreAfterRotation() -> CGFloat {
		var contentScale = self.zoomScale
		
		// If we're at the minimum zoom scale, preserve that by returning 0, which will be converted to the minimum
		// allowable scale when the scale is restored.
		if contentScale <= self.minimumZoomScale + CGFloat.ulpOfOne {
			contentScale = 0
		}
		
		return contentScale
	}
	
	func maximumContentOffset() -> CGPoint {
		let contentSize = self.contentSize
		let boundSize = self.bounds.size
		return CGPoint(x: contentSize.width - boundSize.width, y: contentSize.height - boundSize.height)
	}
	
	func minimumContentOffset() -> CGPoint {
		
		return CGPoint.zero
	}
	
	func restoreCenterPoint(to oldCenter: CGPoint, oldScale: CGFloat) {
		
		// Step 1: restore zoom scale, first making sure it is within the allowable range.
		self.zoomScale = min(self.maximumZoomScale, max(self.minimumZoomScale, oldScale))
		
		
		// Step 2: restore center point, first making sure it is within the allowable range.
		
		// 2a: convert our desired center point back to our own coordinate space
		let boundsCenter = self.convert(oldCenter, from: zoomView)
		// 2b: calculate the content offset that would yield that center point
		var offset = CGPoint(x: boundsCenter.x - self.bounds.size.width/2.0, y: boundsCenter.y - self.bounds.size.height/2.0)
		// 2c: restore offset, adjusted to be within the allowable range
		let maxOffset = self.maximumContentOffset()
		let minOffset = self.minimumContentOffset()
		offset.x = max(minOffset.x, min(maxOffset.x, offset.x))
		offset.y = max(minOffset.y, min(maxOffset.y, offset.y))
		self.contentOffset = offset
	}

	//MARK: - Handle ZoomTap
	
	@objc func handleZoomingTap(_ sender: UITapGestureRecognizer) {
		let location = sender.location(in: sender.view)
		self.zoom(to: location, animated: true)
	}
	
	func zoom(to point: CGPoint, animated: Bool) {
		let currentScale = self.zoomScale
		let minScale = self.minimumZoomScale
		let maxScale = self.maximumZoomScale
		
		if (minScale == maxScale && minScale > 1) {
			return;
		}
		
		let toScale = maxScale
		let finalScale = (currentScale == minScale) ? toScale : minScale
		let zoomRect = self.zoomRect(for: finalScale, withCenter: point)
		self.zoom(to: zoomRect, animated: animated)
	}
	
	
	// The center should be in the imageView's coordinates
	func zoomRect(for scale: CGFloat, withCenter center: CGPoint) -> CGRect {
		var zoomRect = CGRect.zero
		let bounds = self.bounds
		
		// the zoom rect is in the content view's coordinates.
		//At a zoom scale of 1.0, it would be the size of the imageScrollView's bounds.
		//As the zoom scale decreases, so more content is visible, the size of the rect grows.
		zoomRect.size.width = bounds.size.width / scale
		zoomRect.size.height = bounds.size.height / scale
		
		// choose an origin so as to get the right center.
		zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
		zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
		
		return zoomRect
	}
	
	func placeholderImage(in url: URL) -> UIImage? {
		let name = url.deletingPathExtension().lastPathComponent
		let imageName = "\(name)_Placeholder.jpg"
		let url = url.appendingPathComponent(imageName)
		return UIImage(contentsOfFile: url.path)
	}

}
