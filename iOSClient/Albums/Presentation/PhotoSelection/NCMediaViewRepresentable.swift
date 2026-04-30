//
//  NCMediaViewRepresentable.swift
//  Nextcloud
//
//  Created by Dhanesh on 05/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import SwiftUI
import UIKit

struct NCMediaViewRepresentable: UIViewControllerRepresentable {
    @Binding var ncMedia: NCMedia?
    @Binding var selectedCount: Int
    let isSelectionContext: Bool

    var storyboardName: String = "NCMedia"            // <- adjust if different
    var sceneIdentifier: String = "NCMedia.storyboard"   // <- set to your storyboard ID
    var onLoaded: (() -> Void)?

    class Coordinator: NSObject, NCMediaSelectionDelegate {
        var parent: NCMediaViewRepresentable
        init(_ parent: NCMediaViewRepresentable) { self.parent = parent }
        func didUpdateSelection(files: [String]) {
            parent.selectedCount = files.count
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController {
        // 1) Storyboard-based instantiation (preferred)
        let sb = UIStoryboard(name: storyboardName, bundle: .main)
        guard let mediaVC = sb.instantiateViewController(withIdentifier: sceneIdentifier) as? NCMedia else {
            fatalError("Failed to instantiate NCMedia from storyboard. Ensure storyboardName '\(storyboardName)' and sceneIdentifier '\(sceneIdentifier)' are correct, and the class is NCMedia.")
        }

        mediaVC.isInGeneralPhotosSelectionContext = true
        mediaVC.isEditMode = true
        mediaVC.selectionDelegate = context.coordinator
        
        // 2) Hook completion and preload
        mediaVC.onInitialLoadCompleted = { onLoaded?() }
        Task { @MainActor in
            mediaVC.preloadIfNeeded()
        }

        let nav = UINavigationController(rootViewController: mediaVC)
//        nav.modalPresentationStyle = .formSheet
        nav.isNavigationBarHidden = true
        return nav
    }
    
//    func makeUIViewController(context: Context) -> UIViewController {
//        let sb = UIStoryboard(name: "NCMedia", bundle: nil)
//        
//        guard let media = sb.instantiateInitialViewController() as? NCMedia else {
//            return UIViewController()
//        }
//
//        // 1. Force the view to load so IBOutlets (collectionView) are connected
//        media.loadViewIfNeeded()
//        media.isInGeneralPhotosSelectionContext = true
//        media.isEditMode = true
//        media.selectionDelegate = context.coordinator
//
//        // 2. Manually trigger the data loading that the TabBar usually handles
//        Task {
//            await media.loadDataSource()
//            await media.searchMediaUI(true)
//        }
//
//        DispatchQueue.main.async {
//            self.ncMedia = media
//        }
//
//        let nav = UINavigationController(rootViewController: media)
//        nav.isNavigationBarHidden = true
//        return nav
//    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

