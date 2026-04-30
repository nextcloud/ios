// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Your Name
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UIKit

struct NCMediaHost: UIViewControllerRepresentable {
    var storyboardName: String = "NCMedia"            // <- adjust if different
    var sceneIdentifier: String = "NCMedia.storyboard"   // <- set to your storyboard ID
    var onLoaded: (() -> Void)?
    var onSelectionChange: (([String]) -> Void)?
    /// Called when the host's consumer taps Done in a surrounding toolbar and wants to commit selection
    var onDone: (([String]) -> Void)?
    /// Called when the host's consumer taps Back/Cancel
    var onCancel: (() -> Void)?
    var isSelectionContext: Bool = false

    init(
        storyboardName: String = "NCMedia",
        sceneIdentifier: String = "NCMedia.storyboard",
        isSelectionContext: Bool = false,
        onLoaded: (() -> Void)? = nil,
        onSelectionChange: (([String]) -> Void)? = nil,
        onDone: (([String]) -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self.storyboardName = storyboardName
        self.sceneIdentifier = sceneIdentifier
        self.isSelectionContext = isSelectionContext
        self.onLoaded = onLoaded
        self.onSelectionChange = onSelectionChange
        self.onDone = onDone
        self.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        // 1) Storyboard-based instantiation (preferred)
        let sb = UIStoryboard(name: storyboardName, bundle: .main)
        guard let mediaVC = sb.instantiateViewController(withIdentifier: sceneIdentifier) as? NCMedia else {
            fatalError("Failed to instantiate NCMedia from storyboard. Ensure storyboardName '\(storyboardName)' and sceneIdentifier '\(sceneIdentifier)' are correct, and the class is NCMedia.")
        }

        // 2) Hook completion and preload
        mediaVC.onInitialLoadCompleted = { onLoaded?() }
        mediaVC.selectionDelegate = context.coordinator
        mediaVC.isInGeneralPhotosSelectionContext = true
        mediaVC.isEditMode = true
        Task { @MainActor in
            mediaVC.preloadIfNeeded()
        }

        let nav = UINavigationController(rootViewController: mediaVC)
//        nav.modalPresentationStyle = .formSheet
        nav.isNavigationBarHidden = true
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No-op
    }

    class Coordinator:  NSObject, NCMediaSelectionDelegate {
        let parent: NCMediaHost
        private(set) var latestSelection: [String] = []

        init(parent: NCMediaHost) {
            self.parent = parent
        }

        func didUpdateSelection(files: [String]) {
            latestSelection = files
            parent.onSelectionChange?(files)
        }
    }
}

/// Example SwiftUI usage: Present media in a sheet on button tap, preloading content even if the Media tab hasn't been opened.
struct PreloadMediaSheetExample: View {
    @State private var showMedia = false
    @State private var isLoaded = false

    var body: some View {
        VStack(spacing: 20) {
            Button("Open Media (Preloaded)") {
                // Trigger the sheet; the representable will call preload
                showMedia = true
            }
            .buttonStyle(.borderedProminent)

            if isLoaded {
                Text("Media is ready").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showMedia) {
            NCMediaHost {
                // This fires when NCMedia finished its first data load
                isLoaded = true
            }
            .ignoresSafeArea()
        }
    }
}

extension NCMediaHost.Coordinator {
    func currentSelection() -> [String] { latestSelection }
}

#Preview {
    PreloadMediaSheetExample()
}
