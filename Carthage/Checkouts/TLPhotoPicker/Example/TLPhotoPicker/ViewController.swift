//
//  ViewController.swift
//  TLPhotoPicker
//
//  Created by wade.hawk on 05/09/2017.
//  Copyright (c) 2017 wade.hawk. All rights reserved.
//

import UIKit
import TLPhotoPicker
import Photos

class ViewController: UIViewController,TLPhotosPickerViewControllerDelegate {
    
    var selectedAssets = [TLPHAsset]()
    @IBOutlet var label: UILabel!
    @IBOutlet var imageView: UIImageView!
    
    @IBAction func pickerButtonTap() {
        let viewController = CustomPhotoPickerViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        viewController.logDelegate = self

        self.present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func onlyVideoRecording(_ sender: Any) {
        let viewController = CustomPhotoPickerViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        configure.allowedPhotograph = false
        configure.allowedVideoRecording = true
        configure.mediaType = .video
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        viewController.logDelegate = self

        self.present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func pickerWithCustomCameraCell() {
        let viewController = CustomPhotoPickerViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        if #available(iOS 10.2, *) {
            configure.cameraCellNibSet = (nibName: "CustomCameraCell", bundle: Bundle.main)
        }
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        self.present(viewController.wrapNavigationControllerWithoutBar(), animated: true, completion: nil)
    }
    
    @IBAction func pickerWithCustomBlackStyle() {
        let viewController = CustomBlackStylePickerViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        self.present(viewController, animated: true, completion: nil)
    }

    @IBAction func pickerWithNavigation() {
        let viewController = PhotoPickerWithNavigationViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        
        self.present(viewController.wrapNavigationControllerWithoutBar(), animated: true, completion: nil)
    }
    
    @IBAction func pickerWithCustomRules() {
        let viewController = PhotoPickerWithNavigationViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        viewController.canSelectAsset = { [weak self] asset -> Bool in
            if asset.pixelHeight != 300 && asset.pixelWidth != 300 {
                self?.showUnsatisifiedSizeAlert(vc: viewController)
                return false
            }
            return true
        }
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        configure.nibSet = (nibName: "CustomCell_Instagram", bundle: Bundle.main)
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        
        self.present(viewController.wrapNavigationControllerWithoutBar(), animated: true, completion: nil)
    }
    
    @IBAction func pickerWithCustomLayout() {
        let viewController = TLPhotosPickerViewController()
        viewController.delegate = self
        viewController.didExceedMaximumNumberOfSelection = { [weak self] (picker) in
            self?.showExceededMaximumAlert(vc: picker)
        }
        viewController.customDataSouces = CustomDataSources()
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = 3
        configure.groupByFetch = .day
        viewController.configure = configure
        viewController.selectedAssets = self.selectedAssets
        viewController.logDelegate = self
        self.present(viewController, animated: true, completion: nil)
    }
    
    func dismissPhotoPicker(withTLPHAssets: [TLPHAsset]) {
        // use selected order, fullresolution image
        self.selectedAssets = withTLPHAssets
        getFirstSelectedImage()
        //iCloud or video
//        getAsyncCopyTemporaryFile()
    }
    
    func exportVideo() {
        if let asset = self.selectedAssets.first, asset.type == .video {
            asset.exportVideoFile(progressBlock: { (progress) in
                print(progress)
            }) { (url, mimeType) in
                print("completion\(url)")
                print(mimeType)
            }
        }
    }
    
    func getAsyncCopyTemporaryFile() {
        if let asset = self.selectedAssets.first {
            asset.tempCopyMediaFile(convertLivePhotosToJPG: false, progressBlock: { (progress) in
                print(progress)
            }, completionBlock: { (url, mimeType) in
                print("completion\(url)")
                print(mimeType)
            })
        }
    }
    
    func getFirstSelectedImage() {
        if let asset = self.selectedAssets.first {
            if asset.type == .video {
                asset.videoSize(completion: { [weak self] (size) in
                    self?.label.text = "video file size\(size)"
                })
                return
            }
            if let image = asset.fullResolutionImage {
                print(image)
                self.label.text = "local storage image"
                self.imageView.image = image
            }else {
                print("Can't get image at local storage, try download image")
                asset.cloudImageDownload(progressBlock: { [weak self] (progress) in
                    DispatchQueue.main.async {
                        self?.label.text = "download \(100*progress)%"
                        print(progress)
                    }
                }, completionBlock: { [weak self] (image) in
                    if let image = image {
                        //use image
                        DispatchQueue.main.async {
                            self?.label.text = "complete download"
                            self?.imageView.image = image
                        }
                    }
                })
            }
        }
    }
    
    func dismissPhotoPicker(withPHAssets: [PHAsset]) {
        // if you want to used phasset.
    }

    func photoPickerDidCancel() {
        // cancel
    }

    func dismissComplete() {
        // picker dismiss completion
    }

    func didExceedMaximumNumberOfSelection(picker: TLPhotosPickerViewController) {
        self.showExceededMaximumAlert(vc: picker)
    }
    
    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        picker.dismiss(animated: true) {
            let alert = UIAlertController(title: "", message: "Denied albums permissions granted", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        let alert = UIAlertController(title: "", message: "Denied camera permissions granted", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        picker.present(alert, animated: true, completion: nil)
    }

    func showExceededMaximumAlert(vc: UIViewController) {
        let alert = UIAlertController(title: "", message: "Exceed Maximum Number Of Selection", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }
    
    func showUnsatisifiedSizeAlert(vc: UIViewController) {
        let alert = UIAlertController(title: "Oups!", message: "The required size is: 300 x 300", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        vc.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: TLPhotosPickerLogDelegate {
    //For Log User Interaction
    func selectedCameraCell(picker: TLPhotosPickerViewController) {
        print("selectedCameraCell")
    }
    
    func selectedPhoto(picker: TLPhotosPickerViewController, at: Int) {
        print("selectedPhoto")
    }
    
    func deselectedPhoto(picker: TLPhotosPickerViewController, at: Int) {
        print("deselectedPhoto")
    }
    
    func selectedAlbum(picker: TLPhotosPickerViewController, title: String, at: Int) {
        print("selectedAlbum")
    }
}
