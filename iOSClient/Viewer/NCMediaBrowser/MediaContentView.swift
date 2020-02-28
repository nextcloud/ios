//
//  MediaContentView.swift
//  ATGMediaBrowser
//
//  Created by Suraj Thomas K on 7/10/18.
//  Copyright © 2018 Al Tayer Group LLC.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software
//  and associated documentation files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or
//  substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
//  BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

/// Holds the value of minimumZoomScale and maximumZoomScale of the image.
public struct ZoomScale {

    /// Minimum zoom level, the image can be zoomed out to.
    public var minimumZoomScale: CGFloat

    /// Maximum zoom level, the image can be zoomed into.
    public var maximumZoomScale: CGFloat

    /// Default zoom scale. minimum is 1.0 and maximum is 3.0
    public static let `default` = ZoomScale(
        minimum: 1.0,
        maximum: 3.0
    )

    /// Identity zoom scale. Pass this to disable zoom.
    public static let identity = ZoomScale(
        minimum: 1.0,
        maximum: 1.0
    )

    /**
     Initializer.
     - parameter minimum: The minimum zoom level.
     - parameter maximum: The maximum zoom level.
     */
    public init(minimum: CGFloat, maximum: CGFloat) {

        minimumZoomScale = minimum
        maximumZoomScale = maximum
    }
}

internal class MediaContentView: UIScrollView {

    // MARK: - Exposed variables
    internal static var interItemSpacing: CGFloat = 0.0
    internal var index: Int {
        didSet {
            resetZoom()
        }
    }
    internal static var contentTransformer: ContentTransformer = DefaultContentTransformers.horizontalMoveInOut

    internal var position: CGFloat {
        didSet {
            updateTransform()
        }
    }
    internal var image: UIImage? {
        didSet {
            updateImageView()
        }
    }
    internal var isLoading: Bool = false {
        didSet {
            indicatorContainer.isHidden = !isLoading
            if isLoading {
                indicator.startAnimating()
            } else {
                indicator.stopAnimating()
            }
        }
    }
    internal var zoomLevels: ZoomScale? {
        didSet {
            zoomScale = ZoomScale.default.minimumZoomScale
            minimumZoomScale = zoomLevels?.minimumZoomScale ?? ZoomScale.default.minimumZoomScale
            maximumZoomScale = zoomLevels?.maximumZoomScale ?? ZoomScale.default.maximumZoomScale
        }
    }

    // MARK: - Private enumerations

    private enum Constants {

        static let indicatorViewSize: CGFloat = 60.0
    }

    // MARK: - Private variables

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        return imageView
    }()

    private lazy var indicator: UIActivityIndicatorView = {
        let indicatorView = UIActivityIndicatorView()
        indicatorView.style = .whiteLarge
        indicatorView.hidesWhenStopped = true
        return indicatorView
    }()

    private lazy var indicatorContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .darkGray
        container.layer.cornerRadius = Constants.indicatorViewSize * 0.5
        container.layer.masksToBounds = true
        return container
    }()

    private lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap(_:)))
        gesture.numberOfTapsRequired = 2
        gesture.numberOfTouchesRequired = 1
        return gesture
    }()

    init(index itemIndex: Int, position: CGFloat, frame: CGRect) {

        self.index = itemIndex
        self.position = position

        super.init(frame: frame)

        initializeViewComponents()
    }

    required init?(coder aDecoder: NSCoder) {

        fatalError("Do nto use `init?(coder:)`")
    }
}

// MARK: - View Composition and Events

extension MediaContentView {

    private func initializeViewComponents() {

        addSubview(imageView)
        imageView.frame = frame

        setupIndicatorView()

        configureScrollView()

        addGestureRecognizer(doubleTapGestureRecognizer)

        updateTransform()
    }

    private func configureScrollView() {

        isMultipleTouchEnabled = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentSize = imageView.bounds.size
        canCancelContentTouches = false
        zoomLevels = ZoomScale.default
        delegate = self
        bouncesZoom = false
    }

    private func resetZoom() {

        setZoomScale(1.0, animated: false)
        imageView.transform = CGAffineTransform.identity
        contentSize = imageView.frame.size
        contentOffset = .zero
    }

    private func setupIndicatorView() {

        addSubview(indicatorContainer)
        indicatorContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicatorContainer.widthAnchor.constraint(equalToConstant: Constants.indicatorViewSize),
            indicatorContainer.heightAnchor.constraint(equalToConstant: Constants.indicatorViewSize),
            indicatorContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            indicatorContainer.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        indicatorContainer.addSubview(indicator)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            indicator.leadingAnchor.constraint(equalTo: indicatorContainer.leadingAnchor),
            indicator.trailingAnchor.constraint(equalTo: indicatorContainer.trailingAnchor),
            indicator.topAnchor.constraint(equalTo: indicatorContainer.topAnchor),
            indicator.bottomAnchor.constraint(equalTo: indicatorContainer.bottomAnchor)
        ])

        indicatorContainer.setNeedsLayout()
        indicatorContainer.layoutIfNeeded()

        indicatorContainer.isHidden = true
    }

    internal func updateTransform() {

        MediaContentView.contentTransformer(self, position)
    }

    internal func handleChangeInViewSize(to size: CGSize) {

        let oldScale = zoomScale
        zoomScale = 1.0
        imageView.frame = CGRect(origin: .zero, size: size)

        updateImageView()
        updateTransform()
        setZoomScale(oldScale, animated: false)

        contentSize = imageView.frame.size
    }

    @objc private func didDoubleTap(_ recognizer: UITapGestureRecognizer) {

        let locationInImage = recognizer.location(in: imageView)

        let isImageCoveringScreen = imageView.frame.size.width > bounds.size.width &&
            imageView.frame.size.height > bounds.size.height
        let zoomTo = (isImageCoveringScreen || zoomScale == maximumZoomScale) ? minimumZoomScale : maximumZoomScale

        guard zoomTo != zoomScale else {
            return
        }

        let width = bounds.size.width / zoomTo
        let height = bounds.size.height / zoomTo

        let zoomRect = CGRect(
            x: locationInImage.x - width * 0.5,
            y: locationInImage.y - height * 0.5,
            width: width,
            height: height
        )

        zoom(to: zoomRect, animated: true)
    }
}

// MARK: - UIScrollViewDelegate

extension MediaContentView: UIScrollViewDelegate {

    internal func viewForZooming(in scrollView: UIScrollView) -> UIView? {

        let shouldAllowZoom = (image != nil && position == 0.0)
        return shouldAllowZoom ? imageView : nil
    }

    internal func scrollViewDidZoom(_ scrollView: UIScrollView) {

        centerImageView()
    }

    private func centerImageView() {

        var imageViewFrame = imageView.frame

        if imageViewFrame.size.width < bounds.size.width {
            imageViewFrame.origin.x = (bounds.size.width - imageViewFrame.size.width) / 2.0
        } else {
            imageViewFrame.origin.x = 0.0
        }

        if imageViewFrame.size.height < bounds.size.height {
            imageViewFrame.origin.y = (bounds.size.height - imageViewFrame.size.height) / 2.0
        } else {
            imageViewFrame.origin.y = 0.0
        }

        imageView.frame = imageViewFrame
    }

    private func updateImageView() {

        imageView.image = image

        if let contentImage = image {

            let imageViewSize = bounds.size
            let imageSize = contentImage.size
            var targetImageSize = imageViewSize

            if imageSize.width / imageSize.height > imageViewSize.width / imageViewSize.height {
                targetImageSize.height = imageViewSize.width / imageSize.width * imageSize.height
            } else {
                targetImageSize.width = imageViewSize.height / imageSize.height * imageSize.width
            }

            imageView.frame = CGRect(origin: .zero, size: targetImageSize)
        }
        centerImageView()
    }
}
