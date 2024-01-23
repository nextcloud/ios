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
import Queuer
import NextcloudKit

struct MediaCollectionView: UIViewControllerRepresentable {
    @Binding var items: [tableMetadata]

    private var itemsPerRow: [[tableMetadata]] {
        return items.chunked(into: 3)
    }

//    struct CellData {
//        var indexPath: IndexPath
//        var ocId: String
//        var shrinkRatio: CGFloat = 0
//        var isPlaceholderImage = false
//        var scaledSize: CGSize = .zero
//        var imageHeight: CGFloat
//        var imageWidth: CGFloat
//    }

    func makeUIViewController(context: Context) -> ViewController {
        //        let layout = UICollectionViewFlowLayout()
        //        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        //
        //        let viewController = UICollectionViewController(collectionViewLayout: layout)
        //        viewController.collectionView = collectionView
        //
        //
        //        collectionView.dataSource = context.coordinator
        //        collectionView.delegate = context.coordinator
        //
        //        context.coordinator.collectionView = collectionView
        //
        //        let size = viewController.view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        //        viewController.preferredContentSize = size
        //
        //        return viewController

        let coordinator = context.coordinator
        let viewController = ViewController(coordinator: coordinator)
        coordinator.viewController = viewController
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // Update the collection view when items change
        uiViewController.collectionView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension MediaCollectionView {

    final class ViewController: UIViewController {

        fileprivate let layout: UICollectionViewFlowLayout
        fileprivate let collectionView: UICollectionView
        init(coordinator: Coordinator) {
            let layout = UICollectionViewFlowLayout()
//            layout.estimatedItemSize = .init(width: 100, height: 100)
            self.layout = layout

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.backgroundColor = nil
            collectionView.register(MediaCell.self, forCellWithReuseIdentifier: MediaCell.identifier)
            collectionView.dataSource = coordinator
            collectionView.delegate = coordinator
            self.collectionView = collectionView
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("In no way is this class related to an interface builder file.")
        }

        override func loadView() {
            self.view = self.collectionView
        }

        //        override func viewDidLayoutSubviews() {
        //            super.viewDidLayoutSubviews()
        ////            collectionView.collectionViewLayout.invalidateLayout()
        //        }
    }
}

extension MediaCollectionView {

    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, MediaCellDelegate {
        private var metadatas: [tableMetadata] = []
        private let cache = NCImageCache.shared

        private let queuer = NCNetworking.shared.downloadThumbnailQueue

        private let rowWidth = UIScreen.main.bounds.width
        private let spacing: CGFloat = 2

        fileprivate var viewController: ViewController?

        private var cellData: [CellData] = []

        let parent: MediaCollectionView

        init(_ parent: MediaCollectionView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.itemsPerRow[section].count
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return parent.itemsPerRow.count
        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let metadata = parent.itemsPerRow[indexPath.section][indexPath.row]
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
            cell?.delegate = self
            cell?.configure(metadata: metadata, indexPath: indexPath)
            cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
            return cell!
        }

        //        private func calculateShrinkRatio(indexPath: IndexPath) {
        //
        //            let filteredRowData = cellData.enumerated().filter({$0.element.indexPath == indexPath})
        //            if filteredRowData.count == 3 {
        //                filteredRowData.forEach { index, _ in
        //                    cellData[index].scaledSize = getScaledThumbnailSize(of: cellData[index], cellsInRow: filteredRowData.map({ $0.element }))
        //                }
        //            }
        //        }
        //
        //        private func getScaledThumbnailSize(of rowData: CellData, cellsInRow: [CellData] ) -> CGSize {
        //            let maxHeight = cellsInRow.compactMap { $0.imageHeight }.max() ?? 0
        //
        //            let height = rowData.imageHeight
        //            let width = rowData.imageWidth
        //
        //            let scaleFactor = maxHeight / height
        //            let newHeight = height * scaleFactor
        //            let newWidth = width * scaleFactor
        //
        //            return .init(width: newWidth, height: newHeight)
        //        }
        //
        //        private func getShrinkRatio(thumbnailsInRow thumbnails: [ScaledThumbnail], fullWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        //            var newSummedWidth: CGFloat = 0
        //
        //            for thumbnail in thumbnails {
        //                newSummedWidth += CGFloat(thumbnail.scaledSize.width)
        //            }
        //
        //            let spacingWidth = spacing * CGFloat(thumbnails.count - 1)
        //            let shrinkRatio: CGFloat = (fullWidth - spacingWidth) / newSummedWidth
        //
        //            return shrinkRatio
        //        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            //            collectionView.layoutIfNeeded()

//            guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCell else { return .init(width: 100, height: 100) }
//            guard let cellData = cellDataCol.first(where: ({ $0.indexPath == indexPath })) else { return .init(width: 100, height: 100) }

            print(cellDataCol)
            if let cellData = cellDataCol.last(where: ({ $0.indexPath == indexPath })), cellData.shrinkRatio > 0 {
                let width = CGFloat(cellData.scaledWidth * cellData.shrinkRatio)
                let height = CGFloat(cellData.scaledWidth * cellData.shrinkRatio)
//                print("TEST")
//                print(width)
//                print(height)
                return .init(width: width, height: height)
            } else {
//                                print("TEST2")
                return .init(width: 100, height: 100)
            }
        }

//        struct CellData {
//            var indexPath: IndexPath = .init()
//            var newHeight: CGFloat = 0
//            var newWidth: CGFloat = 0
//            var shrinkRatio: CGFloat = 0
//        }
//
        var cellDataCol: [CellData] = []

        struct CellData {
            var height: CGFloat = 0
            var width: CGFloat = 0
            var scaledHeight: CGFloat = 0
            var scaledWidth: CGFloat = 0
            var indexPath: IndexPath = .init()
            var shrinkRatio: CGFloat = 0
        }

        func onImageLoaded(indexPath: IndexPath) {
            var tempCol: [CellData] = []
            let collectionView = viewController?.collectionView

            let section = indexPath.section
            guard let numberOfItems = collectionView?.numberOfItems(inSection: section) else { return }

//            var maxHeight: CGFloat = 0
//            var summedWidth: CGFloat = 0

//            var cellCol: [MediaCell] = []

            for itemNumber in 0..<numberOfItems - 1 {
                var cellData = CellData()
                let indexPath = IndexPath(row: itemNumber, section: section)

                guard let cell = collectionView?.cellForItem(at: indexPath) as? MediaCell else { return }

                cellData.height = cell.image.size.height
                cellData.width = cell.image.size.width
                cellData.indexPath = indexPath

                tempCol.append(cellData)
            }

            let maxHeight = tempCol.compactMap({ $0.height }).max() ?? 0

            for index in tempCol.indices {
                let cellData = tempCol[index]
                let scaleFactor = maxHeight / cellData.height
                var modifiedCellData = cellData
                modifiedCellData.scaledHeight = cellData.height * scaleFactor
                modifiedCellData.scaledWidth = cellData.width * scaleFactor
                tempCol[index] = modifiedCellData
            }

            let summedWidth = tempCol.reduce(0) { sum, cellData in
                return sum + cellData.scaledWidth
            }

            for index in tempCol.indices {
                let cellData = tempCol[index]
                var modifiedCellData = cellData
                modifiedCellData.shrinkRatio = UIScreen.main.bounds.width / summedWidth
                tempCol[index] = modifiedCellData
            }

            cellDataCol.append(contentsOf: tempCol)
            collectionView?.reloadItems(at: [indexPath])
        }
    }

}
