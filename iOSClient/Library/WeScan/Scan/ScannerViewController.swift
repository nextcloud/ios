//
//  ScannerViewController.swift
//  WeScan
//
//  Created by Boris Emorine on 2/8/18.
//  Copyright © 2018 WeTransfer. All rights reserved.
//

import UIKit
import AVFoundation

@available(iOS 10, *)

/// The `ScannerViewController` offers an interface to give feedback to the user regarding quadrilaterals that are detected. It also gives the user the opportunity to capture an image with a detected rectangle.
final class ScannerViewController: UIViewController {
    
    private var captureSessionManager: CaptureSessionManager?
    private let videoPreviewlayer = AVCaptureVideoPreviewLayer()
    
    /// The view that draws the detected rectangles.
    private let quadView = QuadrilateralView()
    
    lazy private var shutterButton: ShutterButton = {
        let button = ShutterButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(captureImage(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy private var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    lazy private var closeButton: CloseButton = {
        let button = CloseButton(frame: CGRect(x: 0, y: 0, width: 18, height: 18))
        button.addTarget(self, action: #selector(cancelImageScannerController(_:)), for: .touchUpInside)
        return button
    }()

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("wescan.scanning.title", comment: "The title of the ScannerViewController")
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)

        setupViews()
        setupConstraints()
        
        captureSessionManager = CaptureSessionManager(videoPreviewLayer: videoPreviewlayer)
        captureSessionManager?.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        quadView.removeQuadrilateral()
        captureSessionManager?.start()
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        videoPreviewlayer.frame = view.layer.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    // MARK: - Setups
    
    private func setupViews() {
        view.layer.addSublayer(videoPreviewlayer)
        quadView.translatesAutoresizingMaskIntoConstraints = false
        quadView.editable = false
        view.addSubview(quadView)
        view.addSubview(shutterButton)
        view.addSubview(activityIndicator)
    }
    
    private func setupConstraints() {
        let quadViewConstraints = [
            quadView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: quadView.bottomAnchor),
            view.trailingAnchor.constraint(equalTo: quadView.trailingAnchor),
            quadView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        ]
        
        var shutterButtonBottomConstraint: NSLayoutConstraint

        if #available(iOS 11.0, *) {
            shutterButtonBottomConstraint = view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 15.0)
        } else {
            shutterButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: shutterButton.bottomAnchor, constant: 15.0)
        }
        
        let shutterButtonConstraints = [
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButtonBottomConstraint,
            shutterButton.widthAnchor.constraint(equalToConstant: 65.0),
            shutterButton.heightAnchor.constraint(equalToConstant: 65.0)
        ]
        
        let activityIndicatorConstraints = [
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        
        NSLayoutConstraint.activate(quadViewConstraints + shutterButtonConstraints + activityIndicatorConstraints)
    }
    
    // MARK: - Actions
    
    @objc private func captureImage(_ sender: UIButton) {
        (navigationController as? ImageScannerController)?.flashToBlack()
        shutterButton.isUserInteractionEnabled = false
        captureSessionManager?.capturePhoto()
    }
    
    @objc private func cancelImageScannerController(_ sender: UIButton) {
        if let imageScannerController = navigationController as? ImageScannerController {
            imageScannerController.imageScannerDelegate?.imageScannerControllerDidCancel(imageScannerController)
        }
    }

}

@available(iOS 10, *)

extension ScannerViewController: RectangleDetectionDelegateProtocol {
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didFailWithError error: Error) {
        
        activityIndicator.stopAnimating()
        shutterButton.isUserInteractionEnabled = true
        
        if let imageScannerController = navigationController as? ImageScannerController {
            imageScannerController.imageScannerDelegate?.imageScannerController(imageScannerController, didFailWithError: error)
        }
    }
    
    func didStartCapturingPicture(for captureSessionManager: CaptureSessionManager) {
        activityIndicator.startAnimating()
        shutterButton.isUserInteractionEnabled = false
    }
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didCapturePicture picture: UIImage, withQuad quad: Quadrilateral?) {
        activityIndicator.stopAnimating()
        
        let editVC = EditScanViewController(image: picture, quad: quad)
        navigationController?.pushViewController(editVC, animated: false)
        
        shutterButton.isUserInteractionEnabled = true
    }
        
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectQuad quad: Quadrilateral?, _ imageSize: CGSize) {
        guard let quad = quad else {
            // If no quad has been detected, we remove the currently displayed on on the quadView.
            quadView.removeQuadrilateral()
            return
        }
        
        let portraitImageSize = CGSize(width: imageSize.height, height: imageSize.width)
        
        let scaleTransform = CGAffineTransform.scaleTransform(forSize: portraitImageSize, aspectFillInSize: quadView.bounds.size)
        let scaledImageSize = imageSize.applying(scaleTransform)
        
        let rotationTransform = CGAffineTransform(rotationAngle: CGFloat(Double.pi / 2.0))

        let imageBounds = CGRect(x: 0.0, y: 0.0, width: scaledImageSize.width, height: scaledImageSize.height).applying(rotationTransform)
        let translationTransform = CGAffineTransform.translateTransform(fromCenterOfRect: imageBounds, toCenterOfRect: quadView.bounds)

        let transforms = [scaleTransform, rotationTransform, translationTransform]
        
        let transformedQuad = quad.applyTransforms(transforms)
        
        quadView.drawQuadrilateral(quad: transformedQuad, animated: true)
    }
    
}
