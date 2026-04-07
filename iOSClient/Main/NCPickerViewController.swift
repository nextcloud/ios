// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2018 Marino Faggiana
// SPDX-FileCopyrightText: 2026 Rasmus Wøldike
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit
import AVFoundation
import SwiftUI
import TLPhotoPicker
import MobileCoreServices
import Photos
import NextcloudKit

// MARK: - Photo Picker

@MainActor
class NCPhotosPickerViewController: NSObject {
    var controller: NCMainTabBarController
    var maxSelectedAssets = 1
    var singleSelectedMode = false
    let global = NCGlobal.shared

    var windowScene: UIWindowScene? {
        SceneManager.shared.getWindowScene(controller: controller)
    }

    @discardableResult
    init(controller: NCMainTabBarController, maxSelectedAssets: Int, singleSelectedMode: Bool) {
        self.controller = controller
        super.init()
        self.maxSelectedAssets = maxSelectedAssets
        self.singleSelectedMode = singleSelectedMode

        openPhotosPickerViewController { assets in
            guard !assets.isEmpty else {
                return
            }
            let model = NCUploadAssetsModel(assets: assets, serverUrl: controller.currentServerUrl(), controller: controller)
            let view = NCUploadAssetsView(model: model)
            let viewController = UIHostingController(rootView: view)

            controller.present(viewController, animated: true, completion: nil)
        }
    }

    private func openPhotosPickerViewController(completition: @escaping ([TLPHAsset]) -> Void) {
        var configure = TLPhotosPickerConfigure()
        var pickerVC: customPhotoPickerViewController?

        configure.cancelTitle = NSLocalizedString("_cancel_", comment: "")
        configure.doneTitle = NSLocalizedString("_add_", comment: "")
        configure.emptyMessage = NSLocalizedString("_no_albums_", comment: "")
        configure.tapHereToChange = NSLocalizedString("_tap_here_to_change_", comment: "")

        if maxSelectedAssets > 0 {
            configure.maxSelectedAssets = maxSelectedAssets
        }
        configure.selectedColor = NCBrandColor.shared.getElement(account: controller.account)
        configure.singleSelectedMode = singleSelectedMode
        configure.allowedAlbumCloudShared = true

        pickerVC = customPhotoPickerViewController(withTLPHAssets: { assets in
            pickerVC?.dismiss(animated: true) {
                completition(assets)
            }
        }, didCancel: nil)
        pickerVC?.ncController = controller

        configure.usedCameraButton = true
        pickerVC?.configure = configure

        pickerVC?.didExceedMaximumNumberOfSelection = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_limited_dimension_", errorCode: NCGlobal.shared.errorInternalError)
            }
        }

        pickerVC?.handleNoAlbumPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_album_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.handleNoCameraPermissions = { _ in
            Task {
                await showErrorBanner(windowScene: self.windowScene, text: "_denied_camera_", errorCode: NCGlobal.shared.errorForbidden)
            }
        }

        pickerVC?.configure = configure
        guard let pickerVC else {
            return
        }

        DispatchQueue.main.async {
            self.controller.present(pickerVC, animated: true, completion: nil)
        }
    }
}

class customPhotoPickerViewController: TLPhotosPickerViewController {

    var ncController: NCMainTabBarController?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyCustomButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyCustomButtons()
    }

    private func applyCustomButtons() {
        guard let navItem = self.customNavItem else { return }

        if navItem.leftBarButtonItems?.contains(where: { $0.action == #selector(customAction) }) == true {
            return
        }

        let closeBtn = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(customAction)
        )
        closeBtn.tintColor = NCBrandColor.shared.iconImageColor

        var leftItems: [UIBarButtonItem] = [closeBtn]

        if PHPhotoLibrary.authorizationStatus() == .limited {
            let selectPhotosBtn = UIBarButtonItem(
                image: UIImage(systemName: "photo.badge.plus"),
                style: .plain,
                target: self,
                action: #selector(selectLimitedPhotos)
            )
            selectPhotosBtn.tintColor = NCBrandColor.shared.iconImageColor
            leftItems.append(selectPhotosBtn)
        }

        navItem.leftBarButtonItems = leftItems
    }

    // MARK: - Actions

    @objc private func selectLimitedPhotos() {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self)
    }

    override func present(_ viewControllerToPresent: UIViewController, animated: Bool, completion: (() -> Void)? = nil) {
        if viewControllerToPresent is UIImagePickerController {
            openMyCustomCamera()
        } else {
            super.present(viewControllerToPresent, animated: animated, completion: completion)
        }
    }

    @objc private func openMyCustomCamera() {
        guard let tabBar = ncController else { return }
        let cameraVC = NCPhotosPickerCameraViewController(controller: tabBar)
        cameraVC.modalPresentationStyle = .fullScreen
        self.present(cameraVC, animated: true)
    }

    @objc private func customAction() {
        self.dismiss(animated: true)
    }
}


@MainActor
class NCPhotosPickerCameraViewController: UIViewController,
                                         AVCapturePhotoCaptureDelegate,
                                         AVCaptureFileOutputRecordingDelegate {

    private var session: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var movieOutput: AVCaptureMovieFileOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var isVideoMode = false
    private var isFlashOn = false
    private var recordingSeconds = 0
    private var recordingTimer: Timer?

    private weak var flashButton: UIButton?
    private weak var shutterInner: UIView?
    private weak var timerLabel: UILabel?
    private weak var recDot: UIView?
    private weak var photoModeBtn: UIButton?
    private weak var videoModeBtn: UIButton?
    private weak var modeSelectorStack: UIStackView?

    private weak var reviewOverlay: UIView?
    private weak var reviewImageView: UIImageView?
    private weak var useButton: UIButton?
    private weak var playButton: UIButton?
    private var capturedURL: URL?
    private var capturedIsVideo = false
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    private weak var zoomLabel: UILabel?
    private var lastZoomFactor: CGFloat = 1.0
    private var wideAngleZoomFactor: CGFloat = 1.0
    private var zoomHideTimer: Timer?

    var controller: NCMainTabBarController!

    // MARK: - Init

    init(controller: NCMainTabBarController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
        setupZoom()
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayer()
        if movieOutput?.isRecording == true {
            movieOutput?.stopRecording()
            stopRecordingTimer()
        }
        UIApplication.shared.isIdleTimerDisabled = false
        session?.stopRunning()
    }

    @objc private func appWillResignActive() {
        if movieOutput?.isRecording == true {
            toggleVideo()
        }
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        session = AVCaptureSession()
        session.sessionPreset = .high

        let camera: AVCaptureDevice?
        if currentCameraPosition == .back {
            camera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        } else {
            camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        guard let camera,
              let videoInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(videoInput) else { return }
        session.addInput(videoInput)

        if let switchOver = camera.virtualDeviceSwitchOverVideoZoomFactors.first.map({ CGFloat($0.doubleValue) }), switchOver > 1 {
            wideAngleZoomFactor = switchOver
            lastZoomFactor = switchOver
            try? camera.lockForConfiguration()
            camera.videoZoomFactor = switchOver
            camera.unlockForConfiguration()
        } else {
            wideAngleZoomFactor = 1.0
            lastZoomFactor = 1.0
        }

        if let audioDevice = AVCaptureDevice.default(for: .audio),
           let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        movieOutput = AVCaptureMovieFileOutput()
        if session.canAddOutput(movieOutput) { session.addOutput(movieOutput) }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    // MARK: - UI

    private func setupUI() {
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        view.addSubview(closeBtn)

        let flashBtn = UIButton(type: .system)
        flashBtn.setImage(UIImage(systemName: "bolt.slash.fill"), for: .normal)
        flashBtn.tintColor = .white
        flashBtn.translatesAutoresizingMaskIntoConstraints = false
        flashBtn.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        view.addSubview(flashBtn)
        self.flashButton = flashBtn

        let dot = UIView()
        dot.backgroundColor = .systemRed
        dot.layer.cornerRadius = 5
        dot.isHidden = true
        dot.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dot)
        self.recDot = dot

        let timerLbl = UILabel()
        timerLbl.text = "00:00"
        timerLbl.textColor = .white
        timerLbl.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        timerLbl.isHidden = true
        timerLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLbl)
        self.timerLabel = timerLbl

        let bottomArea = UIView()
        bottomArea.backgroundColor = .black
        bottomArea.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomArea)

        let photoBtn = UIButton(type: .system)
        photoBtn.setTitle("FOTO", for: .normal)
        photoBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        photoBtn.setTitleColor(.white, for: .normal)
        photoBtn.translatesAutoresizingMaskIntoConstraints = false
        photoBtn.addTarget(self, action: #selector(setPhotoMode), for: .touchUpInside)
        self.photoModeBtn = photoBtn

        let videoBtn = UIButton(type: .system)
        videoBtn.setTitle("VIDEO", for: .normal)
        videoBtn.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        videoBtn.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        videoBtn.translatesAutoresizingMaskIntoConstraints = false
        videoBtn.addTarget(self, action: #selector(setVideoMode), for: .touchUpInside)
        self.videoModeBtn = videoBtn

        let modeStack = UIStackView(arrangedSubviews: [photoBtn, videoBtn])
        modeStack.axis = .horizontal
        modeStack.spacing = 24
        modeStack.translatesAutoresizingMaskIntoConstraints = false
        bottomArea.addSubview(modeStack)
        self.modeSelectorStack = modeStack

        let shutterRing = UIView()
        shutterRing.layer.cornerRadius = 37
        shutterRing.layer.borderWidth = 3
        shutterRing.layer.borderColor = UIColor.white.cgColor
        shutterRing.backgroundColor = .clear
        shutterRing.isUserInteractionEnabled = false
        shutterRing.translatesAutoresizingMaskIntoConstraints = false
        bottomArea.addSubview(shutterRing)

        let innerFill = UIView()
        innerFill.backgroundColor = .white
        innerFill.layer.cornerRadius = 30
        innerFill.isUserInteractionEnabled = false
        innerFill.translatesAutoresizingMaskIntoConstraints = false
        bottomArea.addSubview(innerFill)
        self.shutterInner = innerFill

        let shutterTap = UIButton(type: .custom)
        shutterTap.backgroundColor = .clear
        shutterTap.translatesAutoresizingMaskIntoConstraints = false
        shutterTap.addTarget(self, action: #selector(shutterPressed), for: .touchUpInside)
        bottomArea.addSubview(shutterTap)

        let flipBtn = UIButton(type: .system)
        flipBtn.setImage(UIImage(systemName: "arrow.triangle.2.circlepath.camera.fill"), for: .normal)
        flipBtn.tintColor = .white
        flipBtn.translatesAutoresizingMaskIntoConstraints = false
        flipBtn.addTarget(self, action: #selector(flipCamera), for: .touchUpInside)
        bottomArea.addSubview(flipBtn)

        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeBtn.widthAnchor.constraint(equalToConstant: 44),
            closeBtn.heightAnchor.constraint(equalToConstant: 44),

            flashBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            flashBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            flashBtn.widthAnchor.constraint(equalToConstant: 44),
            flashBtn.heightAnchor.constraint(equalToConstant: 44),

            timerLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: 8),
            timerLbl.centerYAnchor.constraint(equalTo: closeBtn.centerYAnchor),

            dot.centerYAnchor.constraint(equalTo: timerLbl.centerYAnchor),
            dot.trailingAnchor.constraint(equalTo: timerLbl.leadingAnchor, constant: -5),
            dot.widthAnchor.constraint(equalToConstant: 10),
            dot.heightAnchor.constraint(equalToConstant: 10),

            bottomArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomArea.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomArea.heightAnchor.constraint(equalToConstant: 200),

            modeStack.centerXAnchor.constraint(equalTo: bottomArea.centerXAnchor),
            modeStack.topAnchor.constraint(equalTo: bottomArea.topAnchor, constant: 16),

            shutterRing.centerXAnchor.constraint(equalTo: bottomArea.centerXAnchor),
            shutterRing.topAnchor.constraint(equalTo: modeStack.bottomAnchor, constant: 16),
            shutterRing.widthAnchor.constraint(equalToConstant: 74),
            shutterRing.heightAnchor.constraint(equalToConstant: 74),

            innerFill.centerXAnchor.constraint(equalTo: shutterRing.centerXAnchor),
            innerFill.centerYAnchor.constraint(equalTo: shutterRing.centerYAnchor),
            innerFill.widthAnchor.constraint(equalToConstant: 60),
            innerFill.heightAnchor.constraint(equalToConstant: 60),

            shutterTap.centerXAnchor.constraint(equalTo: shutterRing.centerXAnchor),
            shutterTap.centerYAnchor.constraint(equalTo: shutterRing.centerYAnchor),
            shutterTap.widthAnchor.constraint(equalToConstant: 80),
            shutterTap.heightAnchor.constraint(equalToConstant: 80),

            flipBtn.centerYAnchor.constraint(equalTo: shutterRing.centerYAnchor),
            flipBtn.trailingAnchor.constraint(equalTo: bottomArea.trailingAnchor, constant: -40),
            flipBtn.widthAnchor.constraint(equalToConstant: 44),
            flipBtn.heightAnchor.constraint(equalToConstant: 44),
        ])

        let overlay = UIView()
        overlay.backgroundColor = .black
        overlay.isHidden = true
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        self.reviewOverlay = overlay

        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFit
        imgView.backgroundColor = .black
        imgView.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(imgView)
        self.reviewImageView = imgView

        let reviewBar = UIView()
        reviewBar.backgroundColor = .black
        reviewBar.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(reviewBar)

        let retakeBtn = UIButton(type: .system)
        retakeBtn.setTitle(NSLocalizedString("_retake_", comment: ""), for: .normal)
        retakeBtn.setTitleColor(.white, for: .normal)
        retakeBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .regular)
        retakeBtn.translatesAutoresizingMaskIntoConstraints = false
        retakeBtn.addTarget(self, action: #selector(retakeCapture), for: .touchUpInside)
        reviewBar.addSubview(retakeBtn)

        let useBtn = UIButton(type: .system)
        useBtn.setTitleColor(.white, for: .normal)
        useBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        useBtn.translatesAutoresizingMaskIntoConstraints = false
        useBtn.addTarget(self, action: #selector(useCapture), for: .touchUpInside)
        reviewBar.addSubview(useBtn)
        self.useButton = useBtn

        let playBtn = UIButton(type: .system)
        playBtn.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        playBtn.tintColor = .white
        playBtn.isHidden = true
        playBtn.translatesAutoresizingMaskIntoConstraints = false
        playBtn.addTarget(self, action: #selector(togglePlayback), for: .touchUpInside)
        reviewBar.addSubview(playBtn)
        self.playButton = playBtn

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            reviewBar.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            reviewBar.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            reviewBar.bottomAnchor.constraint(equalTo: overlay.bottomAnchor),
            reviewBar.heightAnchor.constraint(equalToConstant: 110),

            imgView.topAnchor.constraint(equalTo: overlay.topAnchor),
            imgView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor),
            imgView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor),
            imgView.bottomAnchor.constraint(equalTo: reviewBar.topAnchor),

            retakeBtn.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 30),
            retakeBtn.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 20),

            playBtn.centerXAnchor.constraint(equalTo: reviewBar.centerXAnchor),
            playBtn.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 14),
            playBtn.widthAnchor.constraint(equalToConstant: 44),
            playBtn.heightAnchor.constraint(equalToConstant: 44),

            useBtn.trailingAnchor.constraint(equalTo: reviewBar.trailingAnchor, constant: -30),
            useBtn.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 20),
        ])
    }

    // MARK: - Mode

    @objc private func setPhotoMode() {
        guard isVideoMode else { return }
        isVideoMode = false
        photoModeBtn?.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        photoModeBtn?.setTitleColor(.white, for: .normal)
        videoModeBtn?.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        videoModeBtn?.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        UIView.animate(withDuration: 0.2) {
            self.shutterInner?.backgroundColor = .white
            self.shutterInner?.layer.cornerRadius = 30
        }
    }

    @objc private func setVideoMode() {
        guard !isVideoMode else { return }
        isVideoMode = true
        videoModeBtn?.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        videoModeBtn?.setTitleColor(.white, for: .normal)
        photoModeBtn?.titleLabel?.font = .systemFont(ofSize: 13, weight: .regular)
        photoModeBtn?.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        UIView.animate(withDuration: 0.2) {
            self.shutterInner?.backgroundColor = .systemRed
            self.shutterInner?.layer.cornerRadius = 30
        }
    }

    // MARK: - Flash

    @objc private func toggleFlash() {
        isFlashOn.toggle()
        flashButton?.setImage(UIImage(systemName: isFlashOn ? "bolt.fill" : "bolt.slash.fill"), for: .normal)
        flashButton?.tintColor = isFlashOn ? .systemYellow : .white
    }

    // MARK: - Actions

    @objc private func closeCamera() {
        dismiss(animated: true)
    }

    @objc private func shutterPressed() {
        if isVideoMode { toggleVideo() } else { takePhoto() }
    }

    @objc private func takePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }

    @objc private func toggleVideo() {
        guard let movieOutput else { return }
        if movieOutput.isRecording {
            movieOutput.stopRecording()
            stopRecordingTimer()
            UIApplication.shared.isIdleTimerDisabled = false
            UIView.animate(withDuration: 0.2) {
                self.shutterInner?.backgroundColor = .systemRed
                self.shutterInner?.layer.cornerRadius = 30
                self.shutterInner?.transform = .identity
            }
            timerLabel?.isHidden = true
            recDot?.isHidden = true
            modeSelectorStack?.isHidden = false
        } else {
            let date = Date()
        let keychain = NCPreferences()
        let fileName = keychain.fileNameOriginal
            ? "VID_\(keychain.incrementalNumber).mov"
            : NCUtilityFileSystem().createFileName("VID.mov", fileDate: date, fileType: .video)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            movieOutput.startRecording(to: url, recordingDelegate: self)
            startRecordingTimer()
            UIApplication.shared.isIdleTimerDisabled = true
            UIView.animate(withDuration: 0.2) {
                self.shutterInner?.layer.cornerRadius = 6
                self.shutterInner?.transform = CGAffineTransform(scaleX: 0.55, y: 0.55)
            }
            timerLabel?.isHidden = false
            recDot?.isHidden = false
            modeSelectorStack?.isHidden = true
        }
    }

    // MARK: - Recording Timer

    private func startRecordingTimer() {
        recordingSeconds = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.recordingSeconds += 1
            let m = self.recordingSeconds / 60
            let s = self.recordingSeconds % 60
            self.timerLabel?.text = String(format: "%02d:%02d", m, s)
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        timerLabel?.text = "00:00"
    }

    // MARK: - Flip Camera

    @objc private func flipCamera() {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        session.beginConfiguration()
        for input in session.inputs.compactMap({ $0 as? AVCaptureDeviceInput }) where input.device.hasMediaType(.video) {
            session.removeInput(input)
        }
        let newCamera: AVCaptureDevice?
        if currentCameraPosition == .back {
            newCamera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInDualWideCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        } else {
            newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }
        guard let newCamera,
              let input = try? AVCaptureDeviceInput(device: newCamera),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.commitConfiguration()

        if let switchOver = newCamera.virtualDeviceSwitchOverVideoZoomFactors.first.map({ CGFloat($0.doubleValue) }), switchOver > 1 {
            wideAngleZoomFactor = switchOver
            lastZoomFactor = switchOver
            try? newCamera.lockForConfiguration()
            newCamera.videoZoomFactor = switchOver
            newCamera.unlockForConfiguration()
        } else {
            wideAngleZoomFactor = 1.0
            lastZoomFactor = 1.0
        }
    }

    // MARK: - Zoom

    private func setupZoom() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        self.zoomLabel = label

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -210),
            label.widthAnchor.constraint(equalToConstant: 60),
            label.heightAnchor.constraint(equalToConstant: 28),
        ])
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = (session?.inputs.compactMap { $0 as? AVCaptureDeviceInput }.first(where: { $0.device.hasMediaType(.video) }))?.device else { return }

        switch gesture.state {
        case .began:
            lastZoomFactor = device.videoZoomFactor
        case .changed:
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0 * wideAngleZoomFactor)
            let minZoom = device.minAvailableVideoZoomFactor
            let newFactor = max(minZoom, min(lastZoomFactor * gesture.scale, maxZoom))
            try? device.lockForConfiguration()
            device.videoZoomFactor = newFactor
            device.unlockForConfiguration()
            showZoomLabel(newFactor)
        default:
            break
        }
    }

    private func showZoomLabel(_ factor: CGFloat) {
        let visualZoom = factor / wideAngleZoomFactor
        let text: String
        if abs(visualZoom - 0.5) < 0.05 {
            text = "0.5×"
        } else if abs(visualZoom - 1.0) < 0.06 {
            text = "1×"
        } else {
            text = String(format: "%.1f×", visualZoom)
        }
        zoomLabel?.text = text
        zoomHideTimer?.invalidate()
        UIView.animate(withDuration: 0.1) { self.zoomLabel?.alpha = 1 }
        zoomHideTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.3) { self?.zoomLabel?.alpha = 0 }
        }
    }

    // MARK: - Review

    private func showReview(url: URL, isVideo: Bool) {
        capturedURL = url
        capturedIsVideo = isVideo
        stopPlayer()

        if isVideo {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                reviewImageView?.image = UIImage(cgImage: cgImage)
            }
            useButton?.setTitle(NSLocalizedString("_use_video_", comment: ""), for: .normal)
            playButton?.isHidden = false
        } else {
            reviewImageView?.image = UIImage(contentsOfFile: url.path)
            useButton?.setTitle(NSLocalizedString("_use_photo_", comment: ""), for: .normal)
            playButton?.isHidden = true
        }

        reviewOverlay?.isHidden = false
    }

    @objc private func retakeCapture() {
        stopPlayer()
        capturedURL = nil
        reviewImageView?.image = nil
        reviewOverlay?.isHidden = true
    }

    // MARK: - Video Playback

    @objc private func togglePlayback() {
        guard let url = capturedURL else { return }
        if let player {
            if player.timeControlStatus == .playing {
                player.pause()
                playButton?.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
            } else {
                player.play()
                playButton?.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            }
        } else {
            let newPlayer = AVPlayer(url: url)
            self.player = newPlayer
            let layer = AVPlayerLayer(player: newPlayer)
            layer.videoGravity = .resizeAspect
            layer.frame = reviewImageView?.bounds ?? .zero
            reviewImageView?.layer.addSublayer(layer)
            self.playerLayer = layer
            newPlayer.play()
            playButton?.setImage(UIImage(systemName: "pause.circle.fill"), for: .normal)
            NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinish),
                                                   name: .AVPlayerItemDidPlayToEndTime, object: newPlayer.currentItem)
        }
    }

    @objc private func playerDidFinish() {
        player?.seek(to: .zero)
        playButton?.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
    }

    private func stopPlayer() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        playButton?.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
    }

    @objc private func useCapture() {
        guard let url = capturedURL else { return }
        presentUploadView(url: url)
    }

    // MARK: - Delegates

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else { return }
        let date = Date()
        let keychain = NCPreferences()
        let fileName = keychain.fileNameOriginal
            ? "IMG_\(keychain.incrementalNumber).JPG"
            : NCUtilityFileSystem().createFileName("IMG.JPG", fileDate: date, fileType: .image)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: url)
        showReview(url: url, isVideo: false)
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        guard error == nil else { return }
        showReview(url: outputFileURL, isVideo: true)
    }

    // MARK: - Upload

    private func presentUploadView(url: URL) {
        let model = NCUploadAssetsModel(tempAssets: [url], serverUrl: controller.currentServerUrl(), controller: controller)
        let uploadView = NCUploadAssetsView(model: model)
        let uploadVC = UIHostingController(rootView: uploadView)
        guard let tabBar = controller else { return }
        tabBar.dismiss(animated: true) {
            tabBar.present(uploadVC, animated: true)
        }
    }
}



    
    
    // MARK: - Document Picker
    
    class NCDocumentPickerViewController: NSObject, UIDocumentPickerDelegate {
        
        let controller: NCMainTabBarController
        var viewController: UIViewController?
        var isViewerMedia: Bool
        
        init(controller: NCMainTabBarController, isViewerMedia: Bool, allowsMultipleSelection: Bool, viewController: UIViewController? = nil) {
            self.controller = controller
            self.isViewerMedia = isViewerMedia
            self.viewController = viewController
            super.init()
            
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
            documentPicker.modalPresentationStyle = .formSheet
            documentPicker.allowsMultipleSelection = allowsMultipleSelection
            documentPicker.delegate = self
            documentPicker.popoverPresentationController?.sourceView = controller.tabBar
            documentPicker.popoverPresentationController?.sourceRect = controller.tabBar.bounds
            
            controller.present(documentPicker, animated: true)
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            Task { @MainActor in
            }
        }
        
        func copySecurityScopedResource(url: URL, urlOut: URL) -> URL? {
            try? FileManager.default.removeItem(at: urlOut)
            if url.startAccessingSecurityScopedResource() {
                do {
                    try FileManager.default.copyItem(at: url, to: urlOut)
                    url.stopAccessingSecurityScopedResource()
                    return urlOut
                } catch {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return nil
        }
    }
