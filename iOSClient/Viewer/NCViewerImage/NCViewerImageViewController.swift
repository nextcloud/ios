//
//  NCViewerImageViewController.swift
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

protocol NCViewerImageViewControllerDataSource: class {
   
    func numberOfItems(in viewerImageViewController: NCViewerImageViewController) -> Int

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, imageAt index: Int, completion: @escaping (_ index: Int, _ image: UIImage?, _ metadata: tableMetadata, _ zoomScale: ZoomScale?, _ error: Error?) -> Void)

    func targetFrameForDismissal(_ viewerImageViewController: NCViewerImageViewController) -> CGRect?
}

extension NCViewerImageViewControllerDataSource {

    public func targetFrameForDismissal(_ viewerImageViewController: NCViewerImageViewController) -> CGRect? { return nil }
}

// MARK: - NCViewerImageViewControllerDelegate protocol

protocol NCViewerImageViewControllerDelegate: class {

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, willChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata)
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata)

    func viewerImageViewControllerTap(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata)
    func viewerImageViewControllerLongPressBegan(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata)
    func viewerImageViewControllerLongPressEnded(_ viewerImageViewController: NCViewerImageViewController, metadata: tableMetadata)

    func viewerImageViewControllerDismiss()
}

extension NCViewerImageViewControllerDelegate {

    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, didChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {}
    func viewerImageViewController(_ viewerImageViewController: NCViewerImageViewController, willChangeFocusTo index: Int, view: NCViewerImageContentView, metadata: tableMetadata) {}
}

public class NCViewerImageViewController: UIViewController {

    // MARK: - Exposed Enumerations

    public enum GestureDirection {

        // Horizontal (left - right) gestures.
        case horizontal
        // Vertical (up - down) gestures.
        case vertical
    }

    public enum BrowserStyle {

        // Linear browser with *0* as first index and *numItems-1* as last index.
        case linear
        // Carousel browser. The media items are repeated in a circular fashion.
        case carousel
    }

    public enum ContentDrawOrder {

        // In this mode, media items are rendered in [previous]-[current]-[next] order.
        case previousToNext
        // In this mode, media items are rendered in [next]-[current]-[previous] order.
        case nextToPrevious
    }

    // MARK: - Exposed variables

    weak var dataSource: NCViewerImageViewControllerDataSource?
    weak var delegate: NCViewerImageViewControllerDelegate?

    var gestureDirection: GestureDirection = .horizontal

    var contentTransformer: NCViewerImageContentTransformer = NCViewerImageDefaultContentTransformers.horizontalMoveInOut {
        didSet {

            NCViewerImageContentView.contentTransformer = contentTransformer
            contentViews.forEach({ $0.updateTransform() })
        }
    }
    
    var drawOrder: ContentDrawOrder = .previousToNext {
        didSet {
            if oldValue != drawOrder {
                mediaContainerView.exchangeSubview(at: 0, withSubviewAt: 2)
            }
        }
    }
    
    var browserStyle: BrowserStyle = .carousel
    // Gap between consecutive media items. Default is `50.0`.
    
    var gapBetweenMediaViews: CGFloat = Constants.gapBetweenContents {
        didSet {
            NCViewerImageContentView.interItemSpacing = gapBetweenMediaViews
            contentViews.forEach({ $0.updateTransform() })
        }
    }
    
    // Enable or disable interactive dismissal. Default is enabled.
    var enableInteractiveDismissal: Bool = true
    
    // Item index of the current item. In range `0..<numMediaItems`
    var currentItemIndex: Int {
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

    public var contentViews: [NCViewerImageContentView] = []

    lazy private var tapGestureRecognizer: UITapGestureRecognizer = { [unowned self] in
        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = 1
        gesture.numberOfTouchesRequired = 1
        gesture.delegate = self
        gesture.addTarget(self, action: #selector(tapGestureEvent(_:)))
        return gesture
    }()
    
    lazy private var longtapGestureRecognizer: UILongPressGestureRecognizer = { [unowned self] in
        let gesture = UILongPressGestureRecognizer()
        gesture.delaysTouchesBegan = true
        gesture.minimumPressDuration = 0.3
        gesture.delegate = self
        gesture.addTarget(self, action: #selector(longpressGestureEvent(_:)))
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
    
    lazy var statusView: UIImageView = {
        let statusView = UIImageView()
        statusView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        statusView.contentMode = .scaleAspectFit
        statusView.clipsToBounds = true
        return statusView
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

    private lazy var dismissController = NCViewerImageDismissAnimationController(
        gestureDirection: gestureDirection,
        viewController: self
    )

    // MARK: - Public methods

    public func reloadContentViews() {

        numMediaItems = dataSource?.numberOfItems(in: self) ?? 0
       
        for contentView in contentViews {

            updateContents(of: contentView)
        }
    }

    // MARK: - Initializers

    init(
        index: Int = 0,
        dataSource: NCViewerImageViewControllerDataSource,
        delegate: NCViewerImageViewControllerDelegate? = nil
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

extension NCViewerImageViewController {

    override public var prefersStatusBarHidden: Bool {

        return true
    }

    override public func viewDidLoad() {

        super.viewDidLoad()

        numMediaItems = dataSource?.numberOfItems(in: self) ?? 0

        populateContentViews()

        view.addGestureRecognizer(panGestureRecognizer)
        view.addGestureRecognizer(tapGestureRecognizer)
        view.addGestureRecognizer(longtapGestureRecognizer)
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
        
        view.addSubview(statusView)
        statusView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            statusView.widthAnchor.constraint(equalToConstant: 30),
            statusView.heightAnchor.constraint(equalToConstant: 30),
            statusView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            statusView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 2)
        ])
       
        statusView.setNeedsLayout()
        statusView.layoutIfNeeded()

        NCViewerImageContentView.interItemSpacing = gapBetweenMediaViews
        NCViewerImageContentView.contentTransformer = contentTransformer

        contentViews.forEach({ $0.removeFromSuperview() })
        contentViews.removeAll()

        for i in -1...1 {
            let mediaView = NCViewerImageContentView(
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

extension NCViewerImageViewController {

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

        guard !dismissController.interactionInProgress else { return }
        guard let mediaView = self.mediaView(at: 1) else { return }
        
        mediaView.zoomScaleOne()
        
        self.delegate?.viewerImageViewControllerTap(self, metadata: mediaView.metadata)
    }
    
    @objc private func longpressGestureEvent(_ recognizer: UITapGestureRecognizer) {
        
        guard !dismissController.interactionInProgress else { return }
        guard let mediaView = self.mediaView(at: 1) else { return }
        
        if recognizer.state == UIGestureRecognizer.State.began {
            mediaView.zoomScaleOne()
            self.delegate?.viewerImageViewControllerLongPressBegan(self, metadata: mediaView.metadata)
        }
        
        if recognizer.state == UIGestureRecognizer.State.ended {
            self.delegate?.viewerImageViewControllerLongPressEnded(self, metadata: mediaView.metadata)
        }
    }
}

// MARK: - Updating View Positions

extension NCViewerImageViewController {

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

            delegate?.viewerImageViewController(self, willChangeFocusTo: index, view: nextView, metadata: nextView.metadata)

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

            delegate?.viewerImageViewController(self, willChangeFocusTo: index, view: previousView, metadata: previousView.metadata)
            
        } else if middleView.position == 0 {
            
            delegate?.viewerImageViewController(self, didChangeFocusTo: index, view: middleView, metadata: middleView.metadata)
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

    private func updateContents(of contentView: NCViewerImageContentView) {

        contentView.image = nil
        let convertedIndex = sanitizeIndex(contentView.index)
        contentView.isLoading = true
        dataSource?.viewerImageViewController(
            self,
            imageAt: convertedIndex,
            completion: { [weak self] (index, image, metadata, zoom, _) in

                guard let strongSelf = self else {
                    return
                }

                if index == strongSelf.sanitizeIndex(contentView.index) {
                    if image != nil {
                        contentView.image = image
                        contentView.metadata = metadata
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

    private func mediaView(at index: Int) -> NCViewerImageContentView? {

        guard index < contentViews.count else {

            assertionFailure("Content views does not have this many views. : \(index)")
            return nil
        }
        return contentViews[index]
    }
}

// MARK: - UIGestureRecognizerDelegate

extension NCViewerImageViewController: UIGestureRecognizerDelegate {

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
            let scrollView = otherGestureRecognizer.view as? NCViewerImageContentView {
            return scrollView.zoomScale == 1.0
        }
        return false
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {

        if gestureRecognizer is UITapGestureRecognizer {
            return otherGestureRecognizer.view is NCViewerImageContentView
        }
        return false
    }
}
