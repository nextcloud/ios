//
//  MediaCollectionView.swift
//  Nextcloud
//
//  Created by Milen on 19.01.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI

struct MediaCollectionView: UIViewControllerRepresentable {
    @Binding var items: [tableMetadata]

    func makeUIViewController(context: Context) -> UICollectionViewController {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 100, height: 100) // Adjust as needed
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        let viewController = UICollectionViewController(collectionViewLayout: layout)
        viewController.collectionView = collectionView

        collectionView.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)

        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator

        return viewController
    }

    func updateUIViewController(_ uiViewController: UICollectionViewController, context: Context) {
        // Update the collection view when items change
        uiViewController.collectionView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        var parent: MediaCollectionView

        init(_ parent: MediaCollectionView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.items.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell else { return UICollectionViewCell() }
            cell.configure(with: parent.items[indexPath.row])
            return cell
        }
    }
}
