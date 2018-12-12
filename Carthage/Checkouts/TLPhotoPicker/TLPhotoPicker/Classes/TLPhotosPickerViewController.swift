//
//  TLPhotosPickerViewController.swift
//  TLPhotosPicker
//
//  Created by wade.hawk on 2017. 4. 14..
//  Copyright © 2017년 wade.hawk. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import MobileCoreServices

public protocol TLPhotosPickerViewControllerDelegate: class {
    func dismissPhotoPicker(withPHAssets: [PHAsset])
    func dismissPhotoPicker(withTLPHAssets: [TLPHAsset])
    func dismissComplete()
    func photoPickerDidCancel()
    func canSelectAsset(phAsset: PHAsset) -> Bool
    func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController)
    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController)
    func handleNoCameraPermissions(picker: TLPhotosPickerViewController)
}

extension TLPhotosPickerViewControllerDelegate {
    public func deninedAuthoization() { }
    public func dismissPhotoPicker(withPHAssets: [PHAsset]) { }
    public func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) { }
    public func dismissComplete() { }
    public func photoPickerDidCancel() { }
    public func canSelectAsset(phAsset: PHAsset) -> Bool { return true }
    public func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController) { }
    public func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) { }
    public func handleNoCameraPermissions(picker: TLPhotosPickerViewController) { }
}

//for log
public protocol TLPhotosPickerLogDelegate: class {
    func selectedCameraCell(picker: TLPhotosPickerViewController)
    func deselectedPhoto(picker: TLPhotosPickerViewController, at: Int)
    func selectedPhoto(picker: TLPhotosPickerViewController, at: Int)
    func selectedAlbum(picker: TLPhotosPickerViewController, title: String, at: Int)
}

extension TLPhotosPickerLogDelegate {
    func selectedCameraCell(picker: TLPhotosPickerViewController) { }
    func deselectedPhoto(picker: TLPhotosPickerViewController, at: Int) { }
    func selectedPhoto(picker: TLPhotosPickerViewController, at: Int) { }
    func selectedAlbum(picker: TLPhotosPickerViewController, collections: [TLAssetsCollection], at: Int) { }
}


public struct TLPhotosPickerConfigure {
    public var defaultCameraRollTitle = "Camera Roll"
    public var tapHereToChange = "Tap here to change"
    public var cancelTitle = "Cancel"
    public var doneTitle = "Done"
    public var emptyMessage = "No albums"
    public var emptyImage: UIImage? = nil
    public var usedCameraButton = true
    public var usedPrefetch = false
    public var allowedLivePhotos = true
    public var allowedVideo = true
    public var allowedAlbumCloudShared = false
    public var allowedVideoRecording = true
    public var recordingVideoQuality: UIImagePickerController.QualityType = .typeMedium
    public var maxVideoDuration:TimeInterval? = nil
    public var autoPlay = true
    public var muteAudio = true
    public var mediaType: PHAssetMediaType? = nil
    public var numberOfColumn = 3
    public var singleSelectedMode = false
    public var maxSelectedAssets: Int? = nil
    public var fetchOption: PHFetchOptions? = nil
    public var selectedColor = UIColor(red: 88/255, green: 144/255, blue: 255/255, alpha: 1.0)
    public var cameraBgColor = UIColor(red: 221/255, green: 223/255, blue: 226/255, alpha: 1)
    public var cameraIcon = TLBundle.podBundleImage(named: "camera")
    public var videoIcon = TLBundle.podBundleImage(named: "video")
    public var placeholderIcon = TLBundle.podBundleImage(named: "insertPhotoMaterial")
    public var nibSet: (nibName: String, bundle:Bundle)? = nil
    public var cameraCellNibSet: (nibName: String, bundle:Bundle)? = nil
    public var fetchCollectionTypes: [(PHAssetCollectionType,PHAssetCollectionSubtype)]? = nil
    public init() {
        
    }
}


public struct Platform {
    
    public static var isSimulator: Bool {
        return TARGET_OS_SIMULATOR != 0 // Use this line in Xcode 7 or newer
    }
    
}


open class TLPhotosPickerViewController: UIViewController {
    @IBOutlet open var titleView: UIView!
    @IBOutlet open var titleLabel: UILabel!
    @IBOutlet open var subTitleStackView: UIStackView!
    @IBOutlet open var subTitleLabel: UILabel!
    @IBOutlet open var subTitleArrowImageView: UIImageView!
    @IBOutlet open var albumPopView: TLAlbumPopView!
    @IBOutlet open var collectionView: UICollectionView!
    @IBOutlet open var indicator: UIActivityIndicatorView!
    @IBOutlet open var popArrowImageView: UIImageView!
    @IBOutlet open var customNavItem: UINavigationItem!
    @IBOutlet open var doneButton: UIBarButtonItem!
    @IBOutlet open var cancelButton: UIBarButtonItem!
    @IBOutlet open var navigationBarTopConstraint: NSLayoutConstraint!
    @IBOutlet open var emptyView: UIView!
    @IBOutlet open var emptyImageView: UIImageView!
    @IBOutlet open var emptyMessageLabel: UILabel!
    
    public weak var delegate: TLPhotosPickerViewControllerDelegate? = nil
    public weak var logDelegate: TLPhotosPickerLogDelegate? = nil
    public var selectedAssets = [TLPHAsset]()
    public var configure = TLPhotosPickerConfigure()
    
    fileprivate var usedCameraButton: Bool {
        get {
            return self.configure.usedCameraButton
        }
    }
    fileprivate var allowedVideo: Bool {
        get {
            return self.configure.allowedVideo
        }
    }
    fileprivate var usedPrefetch: Bool {
        get {
            return self.configure.usedPrefetch
        }
        set {
            self.configure.usedPrefetch = newValue
        }
    }
    fileprivate var allowedLivePhotos: Bool {
        get {
            return self.configure.allowedLivePhotos
        }
        set {
            self.configure.allowedLivePhotos = newValue
        }
    }
    @objc open var canSelectAsset: ((PHAsset) -> Bool)? = nil
    @objc open var didExceedMaximumNumberOfSelection: ((TLPhotosPickerViewController) -> Void)? = nil
    @objc open var handleNoAlbumPermissions: ((TLPhotosPickerViewController) -> Void)? = nil
    @objc open var handleNoCameraPermissions: ((TLPhotosPickerViewController) -> Void)? = nil
    @objc open var dismissCompletion: (() -> Void)? = nil
    fileprivate var completionWithPHAssets: (([PHAsset]) -> Void)? = nil
    fileprivate var completionWithTLPHAssets: (([TLPHAsset]) -> Void)? = nil
    fileprivate var didCancel: (() -> Void)? = nil
    
    fileprivate var collections = [TLAssetsCollection]()
    fileprivate var focusedCollection: TLAssetsCollection? = nil
    fileprivate var requestIds = [IndexPath:PHImageRequestID]()
    fileprivate var playRequestId: (indexPath: IndexPath, requestId: PHImageRequestID)? = nil
    fileprivate var photoLibrary = TLPhotoLibrary()
    fileprivate var queue = DispatchQueue(label: "tilltue.photos.pikcker.queue")
    fileprivate var thumbnailSize = CGSize.zero
    fileprivate var placeholderThumbnail: UIImage? = nil
    fileprivate var cameraImage: UIImage? = nil
    
    deinit {
        //print("deinit TLPhotosPickerViewController")
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init() {
        super.init(nibName: "TLPhotosPickerViewController", bundle: Bundle(for: TLPhotosPickerViewController.self))
    }
    
    @objc convenience public init(withPHAssets: (([PHAsset]) -> Void)? = nil, didCancel: (() -> Void)? = nil) {
        self.init()
        self.completionWithPHAssets = withPHAssets
        self.didCancel = didCancel
    }
    
    convenience public init(withTLPHAssets: (([TLPHAsset]) -> Void)? = nil, didCancel: (() -> Void)? = nil) {
        self.init()
        self.completionWithTLPHAssets = withTLPHAssets
        self.didCancel = didCancel
    }
    
    override open var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIInterfaceOrientationMask.portrait
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        self.stopPlay()
    }
    
    func checkAuthorization() {
        switch PHPhotoLibrary.authorizationStatus() {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] status in
                switch status {
                case .authorized:
                    self?.initPhotoLibrary()
                default:
                    self?.handleDeniedAlbumsAuthorization()
                }
            }
        case .authorized:
            self.initPhotoLibrary()
        case .restricted: fallthrough
        case .denied:
            handleDeniedAlbumsAuthorization()
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        makeUI()
        checkAuthorization()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if self.thumbnailSize == CGSize.zero {
            initItemSize()
        }
        if #available(iOS 11.0, *) {
        } else if self.navigationBarTopConstraint.constant == 0 {
            self.navigationBarTopConstraint.constant = 20
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.photoLibrary.delegate == nil {
            initPhotoLibrary()
        }
    }
}

// MARK: - UI & UI Action
extension TLPhotosPickerViewController {
    
    @objc public func registerNib(nibName: String, bundle: Bundle) {
        self.collectionView.register(UINib(nibName: nibName, bundle: bundle), forCellWithReuseIdentifier: nibName)
    }
    
    fileprivate func centerAtRect(image: UIImage?, rect: CGRect, bgColor: UIColor = UIColor.white) -> UIImage? {
        guard let image = image else { return nil }
        UIGraphicsBeginImageContextWithOptions(rect.size, false, image.scale)
        bgColor.setFill()
        UIRectFill(CGRect(x: 0, y: 0, width: rect.size.width, height: rect.size.height))
        image.draw(in: CGRect(x:rect.size.width/2 - image.size.width/2, y:rect.size.height/2 - image.size.height/2, width:image.size.width, height:image.size.height))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    fileprivate func initItemSize() {
        guard let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let count = CGFloat(self.configure.numberOfColumn)
        let width = (self.view.frame.size.width-(5*(count-1)))/count
        self.thumbnailSize = CGSize(width: width, height: width)
        layout.itemSize = self.thumbnailSize
        self.collectionView.collectionViewLayout = layout
        self.placeholderThumbnail = centerAtRect(image: self.configure.placeholderIcon, rect: CGRect(x: 0, y: 0, width: width, height: width))
        self.cameraImage = centerAtRect(image: self.configure.cameraIcon, rect: CGRect(x: 0, y: 0, width: width, height: width), bgColor: self.configure.cameraBgColor)
    }
    
    @objc open func makeUI() {
        registerNib(nibName: "TLPhotoCollectionViewCell", bundle: Bundle(for: TLPhotoCollectionViewCell.self))
        if let nibSet = self.configure.nibSet {
            registerNib(nibName: nibSet.nibName, bundle: nibSet.bundle)
        }
        if let nibSet = self.configure.cameraCellNibSet {
            registerNib(nibName: nibSet.nibName, bundle: nibSet.bundle)
        }
        self.indicator.startAnimating()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(titleTap))
        self.titleView.addGestureRecognizer(tapGesture)
        self.titleLabel.text = self.configure.defaultCameraRollTitle
        self.subTitleLabel.text = self.configure.tapHereToChange
        self.cancelButton.title = self.configure.cancelTitle
        self.doneButton.title = self.configure.doneTitle
        self.doneButton.setTitleTextAttributes([NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)], for: .normal)
        self.emptyView.isHidden = true
        self.emptyImageView.image = self.configure.emptyImage
        self.emptyMessageLabel.text = self.configure.emptyMessage
        self.albumPopView.tableView.delegate = self
        self.albumPopView.tableView.dataSource = self
        self.popArrowImageView.image = TLBundle.podBundleImage(named: "pop_arrow")
        self.subTitleArrowImageView.image = TLBundle.podBundleImage(named: "arrow")
        if #available(iOS 10.0, *), self.usedPrefetch {
            self.collectionView.isPrefetchingEnabled = true
            self.collectionView.prefetchDataSource = self
        } else {
            self.usedPrefetch = false
        }
        if #available(iOS 9.0, *), self.allowedLivePhotos {
        }else {
            self.allowedLivePhotos = false
        }
    }
    
    fileprivate func updateTitle() {
        guard self.focusedCollection != nil else { return }
        self.titleLabel.text = self.focusedCollection?.title
    }
    
    fileprivate func reloadCollectionView() {
        guard self.focusedCollection != nil else { return }
        self.collectionView.reloadData()
    }
    
    fileprivate func reloadTableView() {
        let count = min(5, self.collections.count)
        var frame = self.albumPopView.popupView.frame
        frame.size.height = CGFloat(count * 75)
        self.albumPopView.popupViewHeight.constant = CGFloat(count * 75)
        UIView.animate(withDuration: self.albumPopView.show ? 0.1:0) {
            self.albumPopView.popupView.frame = frame
            self.albumPopView.setNeedsLayout()
        }
        self.albumPopView.tableView.reloadData()
        self.albumPopView.setupPopupFrame()
    }
    
    fileprivate func initPhotoLibrary() {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            self.photoLibrary.delegate = self
            self.photoLibrary.fetchCollection(configure: self.configure)
        }else{
            //self.dismiss(animated: true, completion: nil)
        }
    }
    
    fileprivate func registerChangeObserver() {
        PHPhotoLibrary.shared().register(self)
    }
    
    fileprivate func getfocusedIndex() -> Int {
        guard let focused = self.focusedCollection, let result = self.collections.index(where: { $0 == focused }) else { return 0 }
        return result
    }
    
    fileprivate func focused(collection: TLAssetsCollection) {
        func resetRequest() {
            cancelAllImageAssets()
        }
        resetRequest()
        self.collections[getfocusedIndex()].recentPosition = self.collectionView.contentOffset
        var reloadIndexPaths = [IndexPath(row: getfocusedIndex(), section: 0)]
        self.focusedCollection = collection
        self.focusedCollection?.fetchResult = self.photoLibrary.fetchResult(collection: collection, configure: self.configure)
        reloadIndexPaths.append(IndexPath(row: getfocusedIndex(), section: 0))
        self.albumPopView.tableView.reloadRows(at: reloadIndexPaths, with: .none)
        self.albumPopView.show(false, duration: 0.2)
        self.updateTitle()
        self.reloadCollectionView()
        self.collectionView.contentOffset = collection.recentPosition
    }
    
    fileprivate func cancelAllImageAssets() {
        for (_,requestId) in self.requestIds {
            self.photoLibrary.cancelPHImageRequest(requestId: requestId)
        }
        self.requestIds.removeAll()
    }
    
    // User Action
    @objc func titleTap() {
        guard collections.count > 0 else { return }
        self.albumPopView.show(self.albumPopView.isHidden)
    }
    
    @IBAction open func cancelButtonTap() {
        self.stopPlay()
        self.dismiss(done: false)
    }
    
    @IBAction open func doneButtonTap() {
        self.stopPlay()
        self.dismiss(done: true)
    }
    
    fileprivate func dismiss(done: Bool) {
        if done {
            #if swift(>=4.1)
            self.delegate?.dismissPhotoPicker(withPHAssets: self.selectedAssets.compactMap{ $0.phAsset })
            #else
            self.delegate?.dismissPhotoPicker(withPHAssets: self.selectedAssets.flatMap{ $0.phAsset })
            #endif
            self.delegate?.dismissPhotoPicker(withTLPHAssets: self.selectedAssets)
            self.completionWithTLPHAssets?(self.selectedAssets)
            #if swift(>=4.1)
            self.completionWithPHAssets?(self.selectedAssets.compactMap{ $0.phAsset })
            #else
            self.completionWithPHAssets?(self.selectedAssets.flatMap{ $0.phAsset })
            #endif
        }else {
            self.delegate?.photoPickerDidCancel()
            self.didCancel?()
        }
        self.dismiss(animated: true) { [weak self] in
            self?.delegate?.dismissComplete()
            self?.dismissCompletion?()
        }
    }
    
    fileprivate func canSelect(phAsset: PHAsset) -> Bool {
        if let closure = self.canSelectAsset {
            return closure(phAsset)
        }else if let delegate = self.delegate {
            return delegate.canSelectAsset(phAsset: phAsset)
        }
        return true
    }
    
    fileprivate func maxCheck() -> Bool {
        if self.configure.singleSelectedMode {
            self.selectedAssets.removeAll()
            self.orderUpdateCells()
        }
        if let max = self.configure.maxSelectedAssets, max <= self.selectedAssets.count {
            self.delegate?.didExceedMaximumNumberOfSelection(picker: self)
            self.didExceedMaximumNumberOfSelection?(self)
            return true
        }
        return false
    }
    fileprivate func focusFirstCollection() {
        if self.focusedCollection == nil, let collection = self.collections.first {
            self.focusedCollection = collection
            self.updateTitle()
            self.reloadCollectionView()
        }
    }
}

// MARK: - TLPhotoLibraryDelegate
extension TLPhotosPickerViewController: TLPhotoLibraryDelegate {
    func loadCameraRollCollection(collection: TLAssetsCollection) {
        self.collections = [collection]
        self.focusFirstCollection()
        self.indicator.stopAnimating()
        self.reloadCollectionView()
        self.reloadTableView()
    }
    
    func loadCompleteAllCollection(collections: [TLAssetsCollection]) {
        self.collections = collections
        self.focusFirstCollection()
        let isEmpty = self.collections.count == 0
        self.subTitleStackView.isHidden = isEmpty
        self.emptyView.isHidden = !isEmpty
        self.emptyImageView.isHidden = self.emptyImageView.image == nil
        self.indicator.stopAnimating()
        self.reloadTableView()
        self.registerChangeObserver()
    }
}

// MARK: - Camera Picker
extension TLPhotosPickerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    fileprivate func showCameraIfAuthorized() {
        let cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorization {
        case .authorized:
            self.showCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] (authorized) in
                DispatchQueue.main.async { [weak self] in
                    if authorized {
                        self?.showCamera()
                    } else {
                        self?.handleDeniedCameraAuthorization()
                    }
                }
            })
        case .restricted, .denied:
            self.handleDeniedCameraAuthorization()
        }
    }

    fileprivate func showCamera() {
        guard !maxCheck() else { return }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = [kUTTypeImage as String]
        if self.configure.allowedVideoRecording {
            picker.mediaTypes.append(kUTTypeMovie as String)
            picker.videoQuality = self.configure.recordingVideoQuality
            if let duration = self.configure.maxVideoDuration {
                picker.videoMaximumDuration = duration
            }
        }
        picker.allowsEditing = false
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    fileprivate func handleDeniedAlbumsAuthorization() {
        self.delegate?.handleNoAlbumPermissions(picker: self)
        self.handleNoAlbumPermissions?(self)
    }
    
    fileprivate func handleDeniedCameraAuthorization() {
        self.delegate?.handleNoCameraPermissions(picker: self)
        self.handleNoCameraPermissions?(self)
    }
    
    open func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    open func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = (info[.originalImage] as? UIImage) {
            var placeholderAsset: PHObjectPlaceholder? = nil
            PHPhotoLibrary.shared().performChanges({
                let newAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholderAsset = newAssetRequest.placeholderForCreatedAsset
            }, completionHandler: { [weak self] (sucess, error) in
                if sucess, let `self` = self, let identifier = placeholderAsset?.localIdentifier {
                    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
                    var result = TLPHAsset(asset: asset)
                    result.selectedOrder = self.selectedAssets.count + 1
                    self.selectedAssets.append(result)
                    self.logDelegate?.selectedPhoto(picker: self, at: 1)
                }
            })
        }
        else if (info[.mediaType] as? String) == kUTTypeMovie as String {
            var placeholderAsset: PHObjectPlaceholder? = nil
            PHPhotoLibrary.shared().performChanges({
                let newAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: info[.mediaURL] as! URL)
                placeholderAsset = newAssetRequest?.placeholderForCreatedAsset
            }) { [weak self] (sucess, error) in
                if sucess, let `self` = self, let identifier = placeholderAsset?.localIdentifier {
                    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
                    var result = TLPHAsset(asset: asset)
                    result.selectedOrder = self.selectedAssets.count + 1
                    self.selectedAssets.append(result)
                    self.logDelegate?.selectedPhoto(picker: self, at: 1)
                }
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UICollectionView Scroll Delegate
extension TLPhotosPickerViewController {
    open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            videoCheck()
        }
    }
    
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        videoCheck()
    }
    
    fileprivate func videoCheck() {
        func play(asset: (IndexPath,TLPHAsset)) {
            if self.playRequestId?.indexPath != asset.0 {
                playVideo(asset: asset.1, indexPath: asset.0)
            }
        }
        guard self.configure.autoPlay else { return }
        guard self.playRequestId == nil else { return }
        let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        #if swift(>=4.1)
        let boundAssets = visibleIndexPaths.compactMap{ indexPath -> (IndexPath,TLPHAsset)? in
            guard let asset = self.focusedCollection?.getTLAsset(at: indexPath.row),asset.phAsset?.mediaType == .video else { return nil }
            return (indexPath,asset)
        }
        #else
        let boundAssets = visibleIndexPaths.flatMap{ indexPath -> (IndexPath,TLPHAsset)? in
            guard let asset = self.focusedCollection?.getTLAsset(at: indexPath.row),asset.phAsset?.mediaType == .video else { return nil }
            return (indexPath,asset)
        }
        #endif
        if let firstSelectedVideoAsset = (boundAssets.filter{ getSelectedAssets($0.1) != nil }.first) {
            play(asset: firstSelectedVideoAsset)
        }else if let firstVideoAsset = boundAssets.first {
            play(asset: firstVideoAsset)
        }
        
    }
}
// MARK: - Video & LivePhotos Control PHLivePhotoViewDelegate
extension TLPhotosPickerViewController: PHLivePhotoViewDelegate {
    fileprivate func stopPlay() {
        guard let playRequest = self.playRequestId else { return }
        self.playRequestId = nil
        guard let cell = self.collectionView.cellForItem(at: playRequest.indexPath) as? TLPhotoCollectionViewCell else { return }
        cell.stopPlay()
    }
    
    fileprivate func playVideo(asset: TLPHAsset, indexPath: IndexPath) {
        stopPlay()
        guard let phAsset = asset.phAsset else { return }
        if asset.type == .video {
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
            let requestId = self.photoLibrary.videoAsset(asset: phAsset, completionBlock: { (playerItem, info) in
                DispatchQueue.main.sync { [weak self, weak cell] in
                    guard let `self` = self, let cell = cell, cell.player == nil else { return }
                    let player = AVPlayer(playerItem: playerItem)
                    cell.player = player
                    player.play()
                    player.isMuted = self.configure.muteAudio
                }
            })
            if requestId > 0 {
                self.playRequestId = (indexPath,requestId)
            }
        }else if asset.type == .livePhoto && self.allowedLivePhotos {
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
            let requestId = self.photoLibrary.livePhotoAsset(asset: phAsset, size: self.thumbnailSize, completionBlock: { [weak cell] (livePhoto,complete) in
                cell?.livePhotoView?.isHidden = false
                cell?.livePhotoView?.livePhoto = livePhoto
                cell?.livePhotoView?.isMuted = true
                cell?.livePhotoView?.startPlayback(with: .hint)
            })
            if requestId > 0 {
                self.playRequestId = (indexPath,requestId)
            }
        }
    }
    
    public func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
        livePhotoView.isMuted = true
        livePhotoView.startPlayback(with: .hint)
    }
    
    public func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    }
}

// MARK: - PHPhotoLibraryChangeObserver
extension TLPhotosPickerViewController: PHPhotoLibraryChangeObserver {
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        guard getfocusedIndex() == 0 else { return }
        let addIndex = self.usedCameraButton ? 1 : 0
        DispatchQueue.main.sync {
            guard let changeFetchResult = self.focusedCollection?.fetchResult else { return }
            guard let changes = changeInstance.changeDetails(for: changeFetchResult) else { return }
            if changes.hasIncrementalChanges {
                var deletedSelectedAssets = false
                var order = 0
                #if swift(>=4.1)
                self.selectedAssets = self.selectedAssets.enumerated().compactMap({ (offset,asset) -> TLPHAsset? in
                    var asset = asset
                    if let phAsset = asset.phAsset, changes.fetchResultAfterChanges.contains(phAsset) {
                        order += 1
                        asset.selectedOrder = order
                        return asset
                    }
                    deletedSelectedAssets = true
                    return nil
                })
                #else
                self.selectedAssets = self.selectedAssets.enumerated().flatMap({ (offset,asset) -> TLPHAsset? in
                    var asset = asset
                    if let phAsset = asset.phAsset, changes.fetchResultAfterChanges.contains(phAsset) {
                        order += 1
                        asset.selectedOrder = order
                        return asset
                    }
                    deletedSelectedAssets = true
                    return nil
                })
                #endif
                if deletedSelectedAssets {
                    self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
                    self.collectionView.reloadData()
                }else {
                    self.collectionView.performBatchUpdates({ [weak self] in
                        guard let `self` = self else { return }
                        self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
                        if let removed = changes.removedIndexes, removed.count > 0 {
                            self.collectionView.deleteItems(at: removed.map { IndexPath(item: $0+addIndex, section:0) })
                        }
                        if let inserted = changes.insertedIndexes, inserted.count > 0 {
                            self.collectionView.insertItems(at: inserted.map { IndexPath(item: $0+addIndex, section:0) })
                        }
                        changes.enumerateMoves { fromIndex, toIndex in
                            self.collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                         to: IndexPath(item: toIndex, section: 0))
                        }
                    }, completion: { [weak self] (completed) in
                        guard let `self` = self else { return }
                        if completed {
                            if let changed = changes.changedIndexes, changed.count > 0 {
                                self.collectionView.reloadItems(at: changed.map { IndexPath(item: $0+addIndex, section:0) })
                            }
                        }
                    })
                }
            }else {
                self.focusedCollection?.fetchResult = changes.fetchResultAfterChanges
                self.collectionView.reloadData()
            }
            if let collection = self.focusedCollection {
                self.collections[getfocusedIndex()] = collection
                self.albumPopView.tableView.reloadRows(at: [IndexPath(row: getfocusedIndex(), section: 0)], with: .none)
            }
        }
    }
}

// MARK: - UICollectionView delegate & datasource
extension TLPhotosPickerViewController: UICollectionViewDelegate,UICollectionViewDataSource,UICollectionViewDataSourcePrefetching {
    fileprivate func getSelectedAssets(_ asset: TLPHAsset) -> TLPHAsset? {
        if let index = self.selectedAssets.index(where: { $0.phAsset == asset.phAsset }) {
            return self.selectedAssets[index]
        }
        return nil
    }
    
    fileprivate func orderUpdateCells() {
        let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row })
        for indexPath in visibleIndexPaths {
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { continue }
            guard let asset = self.focusedCollection?.getTLAsset(at: indexPath.row) else { continue }
            if let selectedAsset = getSelectedAssets(asset) {
                cell.selectedAsset = true
                cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
            }else {
                cell.selectedAsset = false
            }
        }
    }
    
    //Delegate
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let collection = self.focusedCollection, let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
        if collection.useCameraButton && indexPath.row == 0 {
            if Platform.isSimulator {
                print("not supported by the simulator.")
                return
            }else {
                if self.configure.cameraCellNibSet?.nibName != nil {
                    cell.selectedCell()
                }else {
                    showCameraIfAuthorized()
                }
                self.logDelegate?.selectedCameraCell(picker: self)
                return
            }
        }
        guard var asset = collection.getTLAsset(at: indexPath.row), let phAsset = asset.phAsset else { return }
        cell.popScaleAnim()
        if let index = self.selectedAssets.index(where: { $0.phAsset == asset.phAsset }) {
        //deselect
            self.logDelegate?.deselectedPhoto(picker: self, at: indexPath.row)
            self.selectedAssets.remove(at: index)
            #if swift(>=4.1)
            self.selectedAssets = self.selectedAssets.enumerated().compactMap({ (offset,asset) -> TLPHAsset? in
                var asset = asset
                asset.selectedOrder = offset + 1
                return asset
            })
            #else
            self.selectedAssets = self.selectedAssets.enumerated().flatMap({ (offset,asset) -> TLPHAsset? in
                var asset = asset
                asset.selectedOrder = offset + 1
                return asset
            })
            #endif
            cell.selectedAsset = false
            cell.stopPlay()
            self.orderUpdateCells()
            if self.playRequestId?.indexPath == indexPath {
                stopPlay()
            }
        }else {
        //select
            self.logDelegate?.selectedPhoto(picker: self, at: indexPath.row)
            guard !maxCheck() else { return }
            guard canSelect(phAsset: phAsset) else { return }
            asset.selectedOrder = self.selectedAssets.count + 1
            self.selectedAssets.append(asset)
            cell.selectedAsset = true
            cell.orderLabel?.text = "\(asset.selectedOrder)"
            if asset.type != .photo, self.configure.autoPlay {
                playVideo(asset: asset, indexPath: indexPath)
            }
        }
    }
    
    open func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? TLPhotoCollectionViewCell {
            cell.endDisplayingCell()
            cell.stopPlay()
            if indexPath == self.playRequestId?.indexPath {
                self.playRequestId = nil
            }
        }
        guard let requestId = self.requestIds[indexPath] else { return }
        self.requestIds.removeValue(forKey: indexPath)
        self.photoLibrary.cancelPHImageRequest(requestId: requestId)
    }
    
    //Datasource
    open func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        func makeCell(nibName: String) -> TLPhotoCollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: nibName, for: indexPath) as! TLPhotoCollectionViewCell
            cell.configure = self.configure
            cell.imageView?.image = self.placeholderThumbnail
            cell.liveBadgeImageView?.image = nil
            return cell
        }
        let nibName = self.configure.nibSet?.nibName ?? "TLPhotoCollectionViewCell"
        var cell = makeCell(nibName: nibName)
        guard let collection = self.focusedCollection else { return cell }
        cell.isCameraCell = collection.useCameraButton && indexPath.row == 0
        if cell.isCameraCell {
            if let nibName = self.configure.cameraCellNibSet?.nibName {
                cell = makeCell(nibName: nibName)
            }else{
                cell.imageView?.image = self.cameraImage
            }
            cell.willDisplayCell()
            return cell
        }
        guard let asset = collection.getTLAsset(at: indexPath.row) else { return cell }
        if let selectedAsset = getSelectedAssets(asset) {
            cell.selectedAsset = true
            cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
        }else{
            cell.selectedAsset = false
        }
        if asset.state == .progress {
            cell.indicator?.startAnimating()
        }else {
            cell.indicator?.stopAnimating()
        }
        if let phAsset = asset.phAsset {
            if self.usedPrefetch {
                let options = PHImageRequestOptions()
                options.deliveryMode = .opportunistic
                options.resizeMode = .exact
                options.isNetworkAccessAllowed = true
                let requestId = self.photoLibrary.imageAsset(asset: phAsset, size: self.thumbnailSize, options: options) { [weak self, weak cell] (image,complete) in
                    guard let `self` = self else { return }
                    DispatchQueue.main.async {
                        if self.requestIds[indexPath] != nil {
                            cell?.imageView?.image = image
                            cell?.update(with: phAsset)
                            if self.allowedVideo {
                                cell?.durationView?.isHidden = asset.type != .video
                                cell?.duration = asset.type == .video ? phAsset.duration : nil
                            }
                            if complete {
                                self.requestIds.removeValue(forKey: indexPath)
                            }
                        }
                    }
                }
                if requestId > 0 {
                    self.requestIds[indexPath] = requestId
                }
            }else {
                queue.async { [weak self, weak cell] in
                    guard let `self` = self else { return }
                    let requestId = self.photoLibrary.imageAsset(asset: phAsset, size: self.thumbnailSize, completionBlock: { (image,complete) in
                        DispatchQueue.main.async {
                            if self.requestIds[indexPath] != nil {
                                cell?.imageView?.image = image
                                cell?.update(with: phAsset)
                                if self.allowedVideo {
                                    cell?.durationView?.isHidden = asset.type != .video
                                    cell?.duration = asset.type == .video ? phAsset.duration : nil
                                }
                                if complete {
                                    self.requestIds.removeValue(forKey: indexPath)
                                }
                            }
                        }
                    })
                    if requestId > 0 {
                        self.requestIds[indexPath] = requestId
                    }
                }
            }
            if self.allowedLivePhotos {
                cell.liveBadgeImageView?.image = asset.type == .livePhoto ? PHLivePhotoView.livePhotoBadgeImage(options: .overContent) : nil
                cell.livePhotoView?.delegate = asset.type == .livePhoto ? self : nil
            }
        }
        cell.alpha = 0
        UIView.transition(with: cell, duration: 0.1, options: .curveEaseIn, animations: {
            cell.alpha = 1
        }, completion: nil)
        return cell
    }
    
    open func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    open func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let collection = self.focusedCollection else { return 0 }
        return collection.count
    }
    
    //Prefetch
    open func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        if self.usedPrefetch {
            queue.async { [weak self] in
                guard let `self` = self, let collection = self.focusedCollection else { return }
                var assets = [PHAsset]()
                for indexPath in indexPaths {
                    if let asset = collection.getAsset(at: indexPath.row) {
                        assets.append(asset)
                    }
                }
                let scale = max(UIScreen.main.scale,2)
                let targetSize = CGSize(width: self.thumbnailSize.width*scale, height: self.thumbnailSize.height*scale)
                self.photoLibrary.imageManager.startCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
            }
        }
    }
    
    open func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        if self.usedPrefetch {
            for indexPath in indexPaths {
                guard let requestId = self.requestIds[indexPath] else { continue }
                self.photoLibrary.cancelPHImageRequest(requestId: requestId)
                self.requestIds.removeValue(forKey: indexPath)
            }
            queue.async { [weak self] in
                guard let `self` = self, let collection = self.focusedCollection else { return }
                var assets = [PHAsset]()
                for indexPath in indexPaths {
                    if let asset = collection.getAsset(at: indexPath.row) {
                        assets.append(asset)
                    }
                }
                let scale = max(UIScreen.main.scale,2)
                let targetSize = CGSize(width: self.thumbnailSize.width*scale, height: self.thumbnailSize.height*scale)
                self.photoLibrary.imageManager.stopCachingImages(for: assets, targetSize: targetSize, contentMode: .aspectFill, options: nil)
            }
        }
    }
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if self.usedPrefetch, let cell = cell as? TLPhotoCollectionViewCell, let collection = self.focusedCollection, let asset = collection.getTLAsset(at: indexPath.row) {
            if let selectedAsset = getSelectedAssets(asset) {
                cell.selectedAsset = true
                cell.orderLabel?.text = "\(selectedAsset.selectedOrder)"
            }else{
                cell.selectedAsset = false
            }
        }
    }
}

// MARK: - UITableView datasource & delegate
extension TLPhotosPickerViewController: UITableViewDelegate,UITableViewDataSource {
    //delegate
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.logDelegate?.selectedAlbum(picker: self, title: self.collections[indexPath.row].title, at: indexPath.row)
        self.focused(collection: self.collections[indexPath.row])
    }
    
    //datasource
    open func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.collections.count
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TLCollectionTableViewCell", for: indexPath) as! TLCollectionTableViewCell
        let collection = self.collections[indexPath.row]
        cell.titleLabel.text = collection.title
        cell.subTitleLabel.text = "\(collection.fetchResult?.count ?? 0)"
        if let phAsset = collection.getAsset(at: collection.useCameraButton ? 1 : 0) {
            let scale = UIScreen.main.scale
            let size = CGSize(width: 80*scale, height: 80*scale)
            self.photoLibrary.imageAsset(asset: phAsset, size: size, completionBlock: { [weak cell] (image,complete) in
                DispatchQueue.main.async {
                    cell?.thumbImageView.image = image
                }
            })
        }
        cell.accessoryType = getfocusedIndex() == indexPath.row ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }
}
