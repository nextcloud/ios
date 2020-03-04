//
//  MediaBrowserViewController.swift
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

// MARK: - MediaBrowserViewControllerDataSource protocol
/// Protocol to supply media browser contents.
public protocol MediaBrowserViewControllerDataSource: class {

    /**
     Completion block for passing requested media image with details.
     - parameter index: Index of the requested media.
     - parameter image: Image to be passed back to media browser.
     - parameter zoomScale: Zoom scale to be applied to the image including min and max levels.
     - parameter error: Error received while fetching the media image.

     - note:
        Remember to pass the index received in the datasource method back.
        This index is used to set the image to the correct image view.
     */
    typealias CompletionBlock = (_ index: Int, _ image: UIImage?, _ zoomScale: ZoomScale?, _ error: Error?) -> Void

    /**
     Method to supply number of items to be shown in media browser.
     - parameter mediaBrowser: Reference to media browser object.
     - returns: An integer with number of items to be shown in media browser.
     */
    func numberOfItems(in mediaBrowser: MediaBrowserViewController) -> Int

    /**
     Method to supply image for specific index.
     - parameter mediaBrowser: Reference to media browser object.
     - parameter index: Index of the requested media.
     - parameter completion: Completion block to be executed on fetching the media image.
     */
    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, imageAt index: Int, completion: @escaping CompletionBlock)

    /**
     This method is used to get the target frame into which the browser will perform the dismiss transition.
     - parameter mediaBrowser: Reference to media browser object.

     - note:
        If this method is not implemented, the media browser will perform slide up/down transition on dismissal.
    */
    func targetFrameForDismissal(_ mediaBrowser: MediaBrowserViewController) -> CGRect?
}

extension MediaBrowserViewControllerDataSource {

    public func targetFrameForDismissal(_ mediaBrowser: MediaBrowserViewController) -> CGRect? { return nil }
}

// MARK: - MediaBrowserViewControllerDelegate protocol

public protocol MediaBrowserViewControllerDelegate: class {

    /**
     Method invoked on scrolling to next/previous media items.
     - parameter mediaBrowser: Reference to media browser object.
     - parameter index: Index of the newly focussed media item.
     - note:
        This method will not be called on first load, and will be called only on swiping left and right.
     */
    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, didChangeFocusTo index: Int, view: MediaContentView)
    
    func mediaBrowserTap(_ mediaBrowser: MediaBrowserViewController)

    func mediaBrowserDismiss()
}

extension MediaBrowserViewControllerDelegate {

    public func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, didChangeFocusTo index: Int, view: MediaContentView) {}
}

public class MediaBrowserViewController: UIViewController {

    // MARK: - Exposed Enumerations

    /**
     Enum to hold supported gesture directions.

     ```
     case horizontal
     case vertical
     ```
    */
    public enum GestureDirection {

        /// Horizontal (left - right) gestures.
        case horizontal
        /// Vertical (up - down) gestures.
        case vertical
    }

    /**
     Enum to hold supported browser styles.

     ```
     case linear
     case carousel
     ```
     */
    public enum BrowserStyle {

        /// Linear browser with *0* as first index and *numItems-1* as last index.
        case linear
        /// Carousel browser. The media items are repeated in a circular fashion.
        case carousel
    }

    /**
     Enum to hold supported content draw orders.

     ```
     case previousToNext
     case nextToPrevious
     ```
     - note:
        Remember that this is draw order, not positioning. This order decides which item will
     be above or below other items, when they overlap.
     */
    public enum ContentDrawOrder {

        /// In this mode, media items are rendered in [previous]-[current]-[next] order.
        case previousToNext
        /// In this mode, media items are rendered in [next]-[current]-[previous] order.
        case nextToPrevious
    }

    // MARK: - Exposed variables

    /// Data-source object to supply media browser contents.
    public weak var dataSource: MediaBrowserViewControllerDataSource?
    /// Delegate object to get callbacks on media browser events.
    public weak var delegate: MediaBrowserViewControllerDelegate?

    /// Gesture direction. Default is `horizontal`.
    public var gestureDirection: GestureDirection = .horizontal
    /// Content transformer closure. Default is `horizontalMoveInOut`.
    public var contentTransformer: ContentTransformer = DefaultContentTransformers.horizontalMoveInOut {
        didSet {

            MediaContentView.contentTransformer = contentTransformer
            contentViews.forEach({ $0.updateTransform() })
        }
    }
    /// Content draw order. Default is `previousToNext`.
    public var drawOrder: ContentDrawOrder = .previousToNext {
        didSet {
            if oldValue != drawOrder {
                mediaContainerView.exchangeSubview(at: 0, withSubviewAt: 2)
            }
        }
    }
    /// Browser style. Default is carousel.
    public var browserStyle: BrowserStyle = .carousel
    /// Gap between consecutive media items. Default is `50.0`.
    public var gapBetweenMediaViews: CGFloat = Constants.gapBetweenContents {
        didSet {
            MediaContentView.interItemSpacing = gapBetweenMediaViews
            contentViews.forEach({ $0.updateTransform() })
        }
    }
    
    /// Enable or disable interactive dismissal. Default is enabled.
    public var enableInteractiveDismissal: Bool = true
    /// Item index of the current item. In range `0..<numMediaItems`
    public var currentItemIndex: Int {

        return sanitizeIndex(index)
    }
        
    // MARK: - Private Enumerations

    private enum Constants {

        static let gapBetweenContents: CGFloat = 50.0
        static let minimumVelocity: CGFloat = 15.0
        static let minimumTranslation: CGFloat = 0.1
        static let animationDuration = 0.3
        static let updateFrameRate: CGFloat = 60.0
        static let bounceFactor: CGFloat = 0.1

        enum PageControl {

            static let bottom: CGFloat = -10.0
            static let tintColor: UIColor = .lightGray
            static let selectedTintColor: UIColor = .white
        }
    }

    // MARK: - Private variables
    private(set) var index: Int = 0 {
        didSet {
            pageControl.currentPage = index
        }
    }

    public var contentViews: [MediaContentView] = []

    lazy private var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = 1
        gesture.numberOfTouchesRequired = 1
        gesture.delegate = self
        gesture.addTarget(self, action: #selector(tapGestureEvent(_:)))
        return gesture
    }()

    private var previousTranslation: CGPoint = .zero

    private var timer: Timer?
    private var distanceToMove: CGFloat = 0.0

    lazy private var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in
        let gesture = UIPanGestureRecognizer()
        gesture.minimumNumberOfTouches = 1
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = self
        gesture.addTarget(self, action: #selector(panGestureEvent(_:)))
        return gesture
    }()

    lazy internal private(set) var mediaContainerView: UIView = { [unowned self] in
        let container = UIView()
        container.backgroundColor = .clear
        return container
    }()

    lazy private var pageControl: UIPageControl = { [unowned self] in
        let pageControl = UIPageControl()
        pageControl.hidesForSinglePage = true
        pageControl.numberOfPages = numMediaItems
        pageControl.currentPageIndicatorTintColor = Constants.PageControl.selectedTintColor
        pageControl.tintColor = Constants.PageControl.tintColor
        pageControl.currentPage = index
        return pageControl
    }()

    private var numMediaItems = 0

    private lazy var dismissController = DismissAnimationController(
        gestureDirection: gestureDirection,
        viewController: self
    )

    // MARK: - Public methods

    /// Invoking this method reloads the contents media browser.
    public func reloadContentViews() {

        numMediaItems = dataSource?.numberOfItems(in: self) ?? 0
       
        for contentView in contentViews {

            updateContents(of: contentView)
        }
    }

    // MARK: - Initializers

    public init(
        index: Int = 0,
        dataSource: MediaBrowserViewControllerDataSource,
        delegate: MediaBrowserViewControllerDelegate? = nil
        ) {

        self.index = index
        self.dataSource = dataSource
        self.delegate = delegate

        super.init(nibName: nil, bundle: nil)

        initialize()
    }

    public required init?(coder aDecoder: NSCoder) {

        super.init(coder: aDecoder)

        initialize()
    }

    private func initialize() {

        view.backgroundColor = .clear

        modalPresentationStyle = .custom

        modalTransitionStyle = .crossDissolve
    }
    
    public func changeInViewSize(to size: CGSize) {
        self.contentViews.forEach({ $0.handleChangeInViewSize(to: size) })
    }
}

// MARK: - View Lifecycle and Events

extension MediaBrowserViewController {

    override public var prefersStatusBarHidden: Bool {

        return true
    }

    override public func viewDidLoad() {

        super.viewDidLoad()

        numMediaItems = dataSource?.numberOfItems(in: self) ?? 0

        populateContentViews()

        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(tapGestureRecognizer)
    }

    override public func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        contentViews.forEach({ $0.updateTransform() })
    }

    override public func viewWillDisappear(_ animated: Bool) {

        super.viewWillDisappear(animated)
    }
    
    public override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
        ) {

        coordinator.animate(alongsideTransition: { context in
            self.contentViews.forEach({ $0.handleChangeInViewSize(to: size) })
        }, completion: nil)

        super.viewWillTransition(to: size, with: coordinator)
    }

    private func populateContentViews() {

        view.addSubview(mediaContainerView)
        mediaContainerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mediaContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mediaContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mediaContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            mediaContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        MediaContentView.interItemSpacing = gapBetweenMediaViews
        MediaContentView.contentTransformer = contentTransformer

        contentViews.forEach({ $0.removeFromSuperview() })
        contentViews.removeAll()

        for i in -1...1 {
            let mediaView = MediaContentView(
                index: i + index,
                position: CGFloat(i),
                frame: view.bounds
            )
            mediaContainerView.addSubview(mediaView)
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mediaView.leadingAnchor.constraint(equalTo: mediaContainerView.leadingAnchor),
                mediaView.trailingAnchor.constraint(equalTo: mediaContainerView.trailingAnchor),
                mediaView.topAnchor.constraint(equalTo: mediaContainerView.topAnchor),
                mediaView.bottomAnchor.constraint(equalTo: mediaContainerView.bottomAnchor)
            ])

            contentViews.append(mediaView)

            if numMediaItems > 0 {
                updateContents(of: mediaView)
            }
        }
        if drawOrder == .nextToPrevious {
            mediaContainerView.exchangeSubview(at: 0, withSubviewAt: 2)
        }
    }
}

// MARK: - Gesture Recognizers

extension MediaBrowserViewController {

    @objc private func panGestureEvent(_ recognizer: UIPanGestureRecognizer) {

        if dismissController.interactionInProgress {
            dismissController.handleInteractiveTransition(recognizer)
            return
        }

        guard numMediaItems > 0 else {
            return
        }

        let translation = recognizer.translation(in: view)

        switch recognizer.state {
        case .began:
            previousTranslation = translation
            distanceToMove = 0.0
            timer?.invalidate()
            timer = nil
        case .changed:
            moveViews(by: CGPoint(x: translation.x - previousTranslation.x, y: translation.y - previousTranslation.y))
        case .ended, .failed, .cancelled:
            let velocity = recognizer.velocity(in: view)

            var viewsCopy = contentViews
            let previousView = viewsCopy.removeFirst()
            let middleView = viewsCopy.removeFirst()
            let nextView = viewsCopy.removeFirst()

            var toMove: CGFloat = 0.0
            let directionalVelocity = gestureDirection == .horizontal ? velocity.x : velocity.y

            if abs(directionalVelocity) < Constants.minimumVelocity &&
                abs(middleView.position) < Constants.minimumTranslation {
                toMove = -middleView.position
            } else if directionalVelocity < 0.0 {
                if middleView.position >= 0.0 {
                    toMove = -middleView.position
                } else {
                    toMove = -nextView.position
                }
            } else {
                if middleView.position <= 0.0 {
                    toMove = -middleView.position
                } else {
                    toMove = -previousView.position
                }
            }

            if browserStyle == .linear || numMediaItems <= 1 {
                if (middleView.index == 0 && ((middleView.position + toMove) > 0.0)) ||
                    (middleView.index == (numMediaItems - 1) && (middleView.position + toMove) < 0.0) {

                    toMove = -middleView.position
                }
            }

            distanceToMove = toMove

            if timer == nil {
                timer = Timer.scheduledTimer(
                    timeInterval: 1.0/Double(Constants.updateFrameRate),
                    target: self,
                    selector: #selector(update(_:)),
                    userInfo: nil,
                    repeats: true
                )
            }
        default:
            break
        }

        previousTranslation = translation
    }

    @objc private func tapGestureEvent(_ recognizer: UITapGestureRecognizer) {

        guard !dismissController.interactionInProgress else {
            return
        }
        
        if let mediaView = self.mediaView(at: 1) {
            mediaView.zoomScaleOne()
        }

        self.delegate?.mediaBrowserTap(self)
    }
}

// MARK: - Updating View Positions

extension MediaBrowserViewController {

    @objc private func update(_ timeInterval: TimeInterval) {

        guard distanceToMove != 0.0 else {

            timer?.invalidate()
            timer = nil
            return
        }

        let distance = distanceToMove / (Constants.updateFrameRate * 0.1)
        distanceToMove -= distance
        moveViewsNormalized(by: CGPoint(x: distance, y: distance))

        let translation = CGPoint(
            x: distance * (view.frame.size.width + gapBetweenMediaViews),
            y: distance * (view.frame.size.height + gapBetweenMediaViews)
        )
        let directionalTranslation = (gestureDirection == .horizontal) ? translation.x : translation.y
        if abs(directionalTranslation) < 0.1 {

            moveViewsNormalized(by: CGPoint(x: distanceToMove, y: distanceToMove))
            distanceToMove = 0.0
            timer?.invalidate()
            timer = nil
        }
    }

    private func moveViews(by translation: CGPoint) {

        let viewSizeIncludingGap = CGSize(
            width: view.frame.size.width + gapBetweenMediaViews,
            height: view.frame.size.height + gapBetweenMediaViews
        )

        let normalizedTranslation = calculateNormalizedTranslation(
            translation: translation,
            viewSize: viewSizeIncludingGap
        )

        moveViewsNormalized(by: normalizedTranslation)
    }

    private func moveViewsNormalized(by normalizedTranslation: CGPoint) {

        let isGestureHorizontal = (gestureDirection == .horizontal)

        contentViews.forEach({
            $0.position += isGestureHorizontal ? normalizedTranslation.x : normalizedTranslation.y
        })

        var viewsCopy = contentViews
        let previousView = viewsCopy.removeFirst()
        let middleView = viewsCopy.removeFirst()
        let nextView = viewsCopy.removeFirst()

        let viewSizeIncludingGap = CGSize(
            width: view.frame.size.width + gapBetweenMediaViews,
            height: view.frame.size.height + gapBetweenMediaViews
        )

        let viewSize = isGestureHorizontal ? viewSizeIncludingGap.width : viewSizeIncludingGap.height
        let normalizedGap = gapBetweenMediaViews/viewSize
        let normalizedCenter = (middleView.frame.size.width / viewSize) * 0.5
        let viewCount = contentViews.count

        if middleView.position < -(normalizedGap + normalizedCenter) {

            index = sanitizeIndex(index + 1)

            // Previous item is taken and placed on right/down most side
            previousView.position += CGFloat(viewCount)
            previousView.index += viewCount
            updateContents(of: previousView)

            contentViews.removeFirst()
            contentViews.append(previousView)

            switch drawOrder {
            case .previousToNext:
                mediaContainerView.bringSubviewToFront(previousView)
            case .nextToPrevious:
                mediaContainerView.sendSubviewToBack(previousView)
            }

            delegate?.mediaBrowser(self, didChangeFocusTo: index, view: nextView)

        } else if middleView.position > (1 + normalizedGap - normalizedCenter) {

            index = sanitizeIndex(index - 1)

            // Next item is taken and placed on left/top most side
            nextView.position -= CGFloat(viewCount)
            nextView.index -= viewCount
            updateContents(of: nextView)

            contentViews.removeLast()
            contentViews.insert(nextView, at: 0)

            switch drawOrder {
            case .previousToNext:
                mediaContainerView.sendSubviewToBack(nextView)
            case .nextToPrevious:
                mediaContainerView.bringSubviewToFront(nextView)
            }

            delegate?.mediaBrowser(self, didChangeFocusTo: index, view: previousView)
        }
    }

    private func calculateNormalizedTranslation(translation: CGPoint, viewSize: CGSize) -> CGPoint {

        guard let middleView = mediaView(at: 1) else {
            return .zero
        }

        var normalizedTranslation = CGPoint(
            x: (translation.x)/viewSize.width,
            y: (translation.y)/viewSize.height
        )

        if browserStyle != .carousel || numMediaItems <= 1 {
            let isGestureHorizontal = (gestureDirection == .horizontal)
            let directionalTranslation = isGestureHorizontal ? normalizedTranslation.x : normalizedTranslation.y
            if (middleView.index == 0 && ((middleView.position + directionalTranslation) > 0.0)) ||
                (middleView.index == (numMediaItems - 1) && (middleView.position + directionalTranslation) < 0.0) {
                if isGestureHorizontal {
                    normalizedTranslation.x *= Constants.bounceFactor
                } else {
                    normalizedTranslation.y *= Constants.bounceFactor
                }
            }
        }
        return normalizedTranslation
    }

    private func updateContents(of contentView: MediaContentView) {

        contentView.image = nil
        let convertedIndex = sanitizeIndex(contentView.index)
        contentView.isLoading = true
        dataSource?.mediaBrowser(
            self,
            imageAt: convertedIndex,
            completion: { [weak self] (index, image, zoom, _) in

                guard let strongSelf = self else {
                    return
                }

                if index == strongSelf.sanitizeIndex(contentView.index) {
                    if image != nil {
                        contentView.image = image
                        contentView.zoomLevels = zoom
                    }
                    contentView.isLoading = false
                }
            }
        )
    }

    private func sanitizeIndex(_ index: Int) -> Int {

        let newIndex = index % numMediaItems
        if newIndex < 0 {
            return newIndex + numMediaItems
        }
        return newIndex
    }

    private func sourceImage() -> UIImage? {

        return mediaView(at: 1)?.image
    }

    private func mediaView(at index: Int) -> MediaContentView? {

        guard index < contentViews.count else {

            assertionFailure("Content views does not have this many views. : \(index)")
            return nil
        }
        return contentViews[index]
    }
}

// MARK: - UIGestureRecognizerDelegate

extension MediaBrowserViewController: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        guard enableInteractiveDismissal else {
            return true
        }

        let middleView = mediaView(at: 1)
        if middleView?.zoomScale == middleView?.zoomLevels?.minimumZoomScale,
            let recognizer = gestureRecognizer as? UIPanGestureRecognizer {

            let translation = recognizer.translation(in: recognizer.view)

            if gestureDirection == .horizontal {
                dismissController.interactionInProgress = abs(translation.y) > abs(translation.x)
            } else {
                dismissController.interactionInProgress = abs(translation.x) > abs(translation.y)
            }
            if dismissController.interactionInProgress {
                dismissController.image = sourceImage()
            }
        }
        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {

        if gestureRecognizer is UIPanGestureRecognizer,
            let scrollView = otherGestureRecognizer.view as? MediaContentView {
            return scrollView.zoomScale == 1.0
        }
        return false
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {

        if gestureRecognizer is UITapGestureRecognizer {
            return otherGestureRecognizer.view is MediaContentView
        }
        return false
    }
}
