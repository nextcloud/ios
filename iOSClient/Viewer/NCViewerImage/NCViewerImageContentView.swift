//
//  NCViewerImageContentView.swift
//  Nextcloud
//
//  Created by Suraj Thomas K on 7/10/18 Copyright © 2018 Al Tayer Group LLC..
//  Modify for Nextcloud by Marino Faggiana on 04/03/2020.
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

public struct ZoomScale {

    public var minimumZoomScale: CGFloat
    public var maximumZoomScale: CGFloat

    public static let `default` = ZoomScale(
        minimum: 1.0,
        maximum: 5.0
    )

    public static let identity = ZoomScale(
        minimum: 1.0,
        maximum: 1.0
    )

    public init(minimum: CGFloat, maximum: CGFloat) {
        minimumZoomScale = minimum
        maximumZoomScale = maximum
    }
}

public class NCViewerImageContentView: UIScrollView {

    // MARK: - Exposed variables
    
    var metadata = tableMetadata()
    internal static var interItemSpacing: CGFloat = 0.0
    internal var index: Int {
        didSet {
            resetZoom()
        }
    }
    internal static var contentTransformer: NCViewerImageContentTransformer = NCViewerImageDefaultContentTransformers.horizontalMoveInOut

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
        indicatorView.color = .darkGray
        indicatorView.hidesWhenStopped = true
        return indicatorView
    }()

    private lazy var indicatorContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
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

extension NCViewerImageContentView {

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

        NCViewerImageContentView.contentTransformer(self, position)
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
    
    func zoomScaleOne() {
        if zoomScale == 1 { return }
        
        let width = bounds.size.width
        let height = bounds.size.height

        let zoomRect = CGRect(
            x: bounds.size.width/2 - width * 0.5,
            y: bounds.size.height/2 - height * 0.5,
            width: width,
            height: height
        )

        zoom(to: zoomRect, animated: true)
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

extension NCViewerImageContentView: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {

        let shouldAllowZoom = (image != nil && position == 0.0)
        return shouldAllowZoom ? imageView : nil
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {

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
