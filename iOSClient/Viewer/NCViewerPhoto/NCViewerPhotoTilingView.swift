import UIKit

class NCViewerPhotoTilingView: UIView {
	
	var imageName: String
	var url: URL
	var tilingView: NCViewerPhotoTilingView?

	// We use these two properties to avoid accessing tiledLayer from bg thread:
	var storedTileSize: CGSize!
	var storedBounds: CGRect!
	
	override class var layerClass: AnyClass {
		return CATiledLayer.self
	}

	// returns layer property as CATiledLayer
	var tiledLayer: CATiledLayer {
		return self.layer as! CATiledLayer
	}

	/*
	Force contentScaleFactor of 1, even on retina displays For the CATiledLayer
	to handle the interaction between CATiledLayer and high resolution screens, we need to manually set the
	tiling view's contentScaleFactor to 1.0. (If we omitted this, it would be 2.0 on high resolution screens,
	which would cause the CATiledLayer to ask us for tiles of the wrong scales.)
	*/
	override var contentScaleFactor: CGFloat {
		didSet {
			super.contentScaleFactor = 1
		}
	}
	
	init(in url: URL, size: CGSize) {
		self.url = url
		self.imageName = url.deletingPathExtension().lastPathComponent
		
		super.init(frame: CGRect(x: 0, y: 0, width: size.width, height: size.height))
		tiledLayer.levelsOfDetail = 4
		
		storedTileSize = tiledLayer.tileSize
		storedBounds = self.bounds
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
		
		let context = UIGraphicsGetCurrentContext()!
		// get the scale from the context by getting the current transform matrix, then asking for
		// its "a" component, which is one of the two scale components. We need to also ask for the "d" component as it might not be precisely the same as the "a" component, even at the "same" scale.
		let scaleX: CGFloat = context.ctm.a
		let scaleY: CGFloat = context.ctm.d

		var tileSize = self.storedTileSize!
		
		// Even at scales lower than 100%, we are drawing into a rect in the coordinate system of the full
		// image. One tile at 50% covers the width (in original image coordinates) of two tiles at 100%.
		// So at 50% we need to stretch our tiles to double the width and height; at 25% we need to stretch
		// them to quadruple the width and height; and so on.
		// (Note that this means that we are drawing very blurry images as the scale gets low. At 12.5%,
		// our lowest scale, we are stretching about 6 small tiles to fill the entire original image area.
		// But this is okay, because the big blurry image we're drawing here will be scaled way down before
		// it is displayed.)
		
		tileSize.width /= scaleX
		tileSize.height /= -scaleY

		// calculate the rows and columns of tiles that intersect the rect we have been asked to draw
		let firstCol: Int = Int(floor(rect.minX/tileSize.width))
		let lastCol: Int = Int(floor((rect.maxX-1)/tileSize.width))
		let firstRow: Int = Int(floor(rect.minY/tileSize.height))
		let lastRow: Int = Int(floor((rect.maxY-1)/tileSize.height))

		for row in firstRow...lastRow {
			for col in firstCol...lastCol {
				guard let tile = tileFor(scale: scaleX, row: row, col: col) else {
					return
				}
				var tileRect = CGRect(x: tileSize.width*CGFloat(col), y: tileSize.height*CGFloat(row), width: tileSize.width, height: tileSize.height)
				
				// if the tile would stick outside of our bounds, we need to truncate it so as
				// to avoid stretching out the partial tiles at the right and bottom edges
				tileRect = self.storedBounds.intersection(tileRect)
				tile.draw(in: tileRect)
			}
		}

    }
	
	func tileFor(scale: CGFloat, row: Int, col: Int) -> UIImage? {
		//this accounts for a bug somewhere upstream that returns the scale as a floating point number just below the required value: 0.249... instead of 0.2500
		let scale = scale < 1.0 ? Int(1/CGFloat(Int(1/scale))*1000) : Int(scale*1000)
		
		// we use "UIImage(contentsOfFile:)" instead of "UIImage(named:)" here because we don't
		// want UIImage to cache our tiles
		let tileName = "\(self.imageName)_\(scale)_\(col)_\(row).png"
		
		let path = url.appendingPathComponent(tileName).path
		let image = UIImage(contentsOfFile: path)
		return image
	}
}
