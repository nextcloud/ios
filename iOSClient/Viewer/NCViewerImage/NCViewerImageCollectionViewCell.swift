
import UIKit

protocol NCViewerImageCollectionViewCellDelegate: class {
    func didStartZooming(_ cell: NCViewerImageCollectionViewCell)
}

class NCViewerImageCollectionViewCell: UICollectionViewCell {
    static var reusableIdentifier: String = "NCViewerImageCollectionViewCell"

    private var dataTask: URLSessionDataTask?
    weak var delegate: NCViewerImageCollectionViewCellDelegate?

    @IBOutlet weak var imageWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var imageHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var topConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var galleryImageView: UIImageView!
    @IBOutlet weak var leadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var trailingConstraint: NSLayoutConstraint!

    private var observer: NSKeyValueObservation?

    func withImageAsset(_ asset: NCViewerImageAsset?) {
        guard self.dataTask?.state != URLSessionDataTask.State.running else { return }
        guard let asset = asset else { return }
        guard let metadata = asset.metadata else { return }
        let imagePath = CCUtility.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)!
        if let image = UIImage(contentsOfFile: imagePath) {
            self.apply(image: self.fitIntoFrame(image: image, type: asset.type))
        }
        /*
        if asset.image != nil {
            self.apply(image: self.fitIntoFrame(image: asset.image, type: asset.type))
        } else if asset.url != nil {
            self.galleryImageView.image = nil
            self.dataTask = asset.download(completion: { _ in
                self.apply(image: self.fitIntoFrame(image: asset.image, type: asset.type))
            })
        }
        */
    }

    func apply(image: UIImage?) {
        guard let image = image else { return }
//        self.galleryImageView.alpha = 0
        self.galleryImageView.image = image
//        UIView.animate(withDuration: 0.1) {
//            self.galleryImageView.alpha = 1
//        }
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        self.scrollView.maximumZoomScale = 4
        self.redrawConstraintIfNeeded()
        self.observer = self.observe(\.bounds, options: NSKeyValueObservingOptions.new, changeHandler: { (_, _) in
            self.apply(image: self.fitIntoFrame(image: self.galleryImageView.image, type: nil))
            self.redrawConstraintIfNeeded()
        })
    }

    func cancelPendingDataTask() {
        self.dataTask?.cancel()
    }

    override func layoutSubviews() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.redrawConstraintIfNeeded()
        }
        super.layoutSubviews()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        self.scrollView.setZoomScale(1, animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // limitation of cell lifecycle
            self.redrawConstraintIfNeeded()
        }
    }

    func setMargins(vertical: CGFloat, horizontal: CGFloat) {
        self.topConstraint.constant = vertical
        self.bottomConstraint.constant = vertical
        self.leadingConstraint.constant = horizontal
        self.trailingConstraint.constant = horizontal
    }

    func redrawConstraintIfNeeded() {
        let imageHeight = self.galleryImageView.frame.size.height
        let imageWidth = self.galleryImageView.frame.size.width
        let spaceLeftVertical = self.scrollView.frame.size.height-imageHeight
        let spaceLeftHorizontal = self.scrollView.frame.size.width-imageWidth
        let constraintConstantValueVertical = spaceLeftVertical/2 > 0 ? spaceLeftVertical/2 : 0
        let constraintConstantValueHorizontal = spaceLeftHorizontal/2 > 0 ? spaceLeftHorizontal/2 : 0
        self.setMargins(vertical: constraintConstantValueVertical, horizontal: constraintConstantValueHorizontal)
        self.layoutIfNeeded()
    }

    private func fitIntoFrame(image: UIImage?, type: NCViewerImageAsset.ImageType?) -> UIImage? {
        let type: NCViewerImageAsset.ImageType = type ?? .jpg
        guard let image = image else { return nil }
        guard image.size != CGSize.zero else { return nil }
        let screenRatio = UIScreen.main.bounds.size.width/UIScreen.main.bounds.size.height
        var reqWidth: CGFloat = frame.size.width
        if image.size.width > reqWidth {
            reqWidth = image.size.width
        }
        let imageRatio = image.size.width/image.size.height
        if imageRatio < screenRatio {
            reqWidth = frame.size.height*imageRatio
        }
        let size = CGSize(width: reqWidth, height: reqWidth/imageRatio)
        if imageRatio < screenRatio {
            self.imageHeightConstraint.constant = frame.size.height
            self.imageWidthConstraint.constant = frame.size.height*imageRatio
        } else {
            self.imageHeightConstraint.constant = frame.size.width/imageRatio
            self.imageWidthConstraint.constant = frame.size.width
        }
        switch type {
        case .gif: return image
        case .jpg:
            UIGraphicsBeginImageContext(size)
            image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            let finalImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return finalImage
        }
    }

    func redrawImage() {
        self.apply(image: self.fitIntoFrame(image: self.galleryImageView.image, type: nil))
        self.redrawConstraintIfNeeded()
    }
}

extension NCViewerImageCollectionViewCell: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.galleryImageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        self.delegate?.didStartZooming(self)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.redrawConstraintIfNeeded()
    }
}
