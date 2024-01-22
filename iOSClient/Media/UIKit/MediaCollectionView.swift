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

    func makeUIViewController(context: Context) -> ViewController {
//        let layout = UICollectionViewFlowLayout()
//        //        layout.itemSize = CGSize(width: 100, height: 100) // Adjust as needed
//        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
//
//        let viewController = ViewController(coordinator: context.coordinator)
//        context.coordinator.viewController = viewController
//        viewController.collectionView = collectionView

//        collectionView.dataSource = context.coordinator
//        collectionView.delegate = context.coordinator

        let coordinator = context.coordinator
                let viewController = ViewController(coordinator: coordinator)
                coordinator.viewController = viewController
//                self.rawCustomize?(viewController.collectionView)

        //        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
        //            //            flowLayout.minimumInteritemSpacing = 0
        //            //            flowLayout.minimumLineSpacing = 2
        //            //            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        //
        //        }

        //        collectionView.sepera

        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        // Update the collection view when items change
        context.coordinator.parent = self
        uiViewController.collectionView.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

extension MediaCollectionView {

    final class ViewController : UIViewController {

        fileprivate let layout: UICollectionViewFlowLayout
        fileprivate let collectionView: UICollectionView
        init(coordinator: Coordinator) {
            let layout = UICollectionViewFlowLayout()
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
    }
}

extension MediaCollectionView {


    // MARK: - Coordinator
    class Coordinator: NSObject, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
        private(set) var rowData = RowData()

        private var metadatas: [tableMetadata] = []
        private let cache = NCImageCache.shared

        private let queuer = NCNetworking.shared.downloadThumbnailQueue

        private let rowWidth = UIScreen.main.bounds.width
        private let spacing: CGFloat = 2

        fileprivate var parent: MediaCollectionView
           fileprivate var viewController: ViewController?

           init(_ parent: MediaCollectionView) {
               self.parent = parent
           }

//        let parent: MediaCollectionView
        //        let cellsPerRow: [[tableMetadata]]

//        init(_ parent: MediaCollectionView) {
//            self.parent = parent
//            //            cellsPerRow = parent.items.chunked(into: 3)
//            //            print("TEST")
//            //            print(cellsPerRow)
//            //            print(cellsPerRow.count)
//        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.itemsPerRow[section].count
        }

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return parent.itemsPerRow.count
        }

        //        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //            return groups[section].items.count
        //        }
        //
        //        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        //            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        //            // Configure the cell
        //            return cell
        //        }
        //
        //        struct RowData {
        //            var scaledThumbnails: [ScaledThumbnail] = []
        //            var shrinkRatio: CGFloat = 0
        //        }
        //
        //        struct ScaledThumbnail: Hashable {
        //            let image: UIImage
        //            var isPlaceholderImage = false
        //            var scaledSize: CGSize = .zero
        //            let metadata: tableMetadata
        //
        //            func hash(into hasher: inout Hasher) {
        //                hasher.combine(metadata.ocId)
        //            }
        //        }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//            let metadatas = parent.itemsPerRow[indexPath.section]
//            print(metadatas.forEach({ $0.fileName
//            }))
//            var thumbnails: [ScaledThumbnail] = []
//
//            //            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//            //
//            //            return cell!
//
//            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//            //            cell?.configure(metadatas: metadatas, index: indexPath.row)
//
//            for metadata in metadatas {
//                let thumbnailPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)
//                if let cachedImage = cache.getMediaImage(ocId: metadata.ocId, etag: metadata.etag) {
//                    let thumbnail: ScaledThumbnail
//
//                    if case let .actual(image) = cachedImage {
//                        thumbnail = ScaledThumbnail(image: image, metadata: metadata)
//                    } else {
//                        let image = UIImage(systemName: metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
//                        thumbnail = ScaledThumbnail(image: image, isPlaceholderImage: true, metadata: metadata)
//                    }
//
//                    //                    DispatchQueue.main.async {
//                    thumbnails.append(thumbnail)
//                    self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//                    //                        collectionView.collectionViewLayout.invalidateLayout()
//
//                    //                    }
//                } else if FileManager.default.fileExists(atPath: thumbnailPath) {
//                    // Load thumbnail from file
//                    if let image = UIImage(contentsOfFile: thumbnailPath) {
//                        let thumbnail = ScaledThumbnail(image: image, metadata: metadata)
//                        cache.setMediaImage(ocId: metadata.ocId, etag: metadata.etag, image: .actual(image))
//
//                        //                        DispatchQueue.main.async {
//                        thumbnails.append(thumbnail)
//                        self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//                        //                            collectionView.collectionViewLayout.invalidateLayout()
//                        //                        }
//                    }
//                } else {
//                    if queuer.operations.filter({ ($0 as? NCMediaDownloadThumbnaill)?.metadata.ocId == metadata.ocId }).isEmpty {
//                        let concurrentOperation = NCMediaDownloadThumbnaill(metadata: metadata, cache: cache, rowWidth: rowWidth, spacing: spacing, maxWidth: UIScreen.main.bounds.width, maxHeight: UIScreen.main.bounds.height) { thumbnail in
//                            //                            DispatchQueue.main.async {
//                            thumbnails.append(thumbnail)
//                            self.calculateShrinkRatio(metadatas: self.metadatas, rowData: &self.rowData, thumbnails: &thumbnails, rowWidth: self.rowWidth, spacing: self.spacing)
//                            //                                collectionView.collectionViewLayout.invalidateLayout()
//                            //                            }
//                        }
//
//                        queuer.addOperation(concurrentOperation)
//                    }
//                }
//
//                if indexPath.row < thumbnails.count{
//                    let thumbnail = thumbnails[indexPath.row]
//                    cell?.configure(metadatas: metadatas, index: indexPath.row, thumbnail: thumbnail)
//                }
//
//                //                            print("TEST")
//                //                            print(thumbnails.count)
//                //                            if thumbnails.count == 3 {
//                //                                let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//                //                                let metadata = metadatas[indexPath.row]
//                //                                cell?.backgroundColor = .black
//                //                                return cell!
//                //                            }
//
//
//                //
//                //                cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
//                //                return cell!
//            }
//            //
//
//
//            //            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell else { return UICollectionViewCell() }
//            //            cell.configure(metadata: parent.itemsPerRow[indexPath.section][indexPath.row])
//            //            cell.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
//            cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)
//            return cell!

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MediaCell.identifier, for: indexPath) as? MediaCell
//            let data = self.view.collections[indexPath.section][indexPath.item]
//            let content = self.view.contentForData(data)
//            cell?.provide(content)
            cell?.backgroundColor = UIColor(hue: CGFloat(drand48()), saturation: 1, brightness: 1, alpha: 1)

            return cell!
        }



//        private func calculateShrinkRatio(metadatas: [tableMetadata], rowData: inout RowData, thumbnails: inout [ScaledThumbnail], rowWidth: CGFloat, spacing: CGFloat) {
//            if thumbnails.count == metadatas.count {
//                thumbnails.enumerated().forEach { index, thumbnail in
//                    thumbnails[index].scaledSize = getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
//                }
//
//                let shrinkRatio = getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: rowWidth, spacing: spacing)
//
//                rowData.scaledThumbnails = thumbnails
//                rowData.shrinkRatio = shrinkRatio
//            }
//        }
//
//        private func getScaledThumbnailSize(of thumbnail: ScaledThumbnail, thumbnailsInRow thumbnails: [ScaledThumbnail]) -> CGSize {
//            let maxHeight = thumbnails.compactMap { CGFloat($0.image.size.height) }.max() ?? 0
//
//            let height = thumbnail.image.size.height
//            let width = thumbnail.image.size.width
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

//        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//            let noOfCellsInRow = 3   // number of column you want
//            guard let flowLayout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
//            //            flowLayout.minimumInteritemSpacing = 0
//            //            flowLayout.minimumLineSpacing = 2
//            //            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
//            let totalSpace = flowLayout.sectionInset.left
//            + flowLayout.sectionInset.right
//            + (flowLayout.minimumInteritemSpacing * CGFloat(noOfCellsInRow - 1))
//
//            let size = Int((collectionView.bounds.width - totalSpace) / CGFloat(noOfCellsInRow))
//            return CGSize(width: Double.random(in: 50...200), height: Double.random(in: 50...200))
//        }

        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
            return .init(width: 200, height: 100)
        }


    }
}

class NCMediaDownloadThumbnaill: ConcurrentOperation {
    let metadata: tableMetadata
    let cache: NCImageCache
    let rowWidth: CGFloat
    let spacing: CGFloat
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    let onThumbnailDownloaded: (ScaledThumbnail) -> Void

    init(metadata: tableMetadata, cache: NCImageCache, rowWidth: CGFloat, spacing: CGFloat, maxWidth: CGFloat, maxHeight: CGFloat, onThumbnailDownloaded: @escaping (ScaledThumbnail) -> Void) {
        self.metadata = metadata
        self.cache = cache
        self.rowWidth = rowWidth
        self.spacing = spacing
        self.maxWidth = maxWidth
        self.maxHeight = maxHeight
        self.onThumbnailDownloaded = onThumbnailDownloaded
    }

    override func start() {
        guard !isCancelled else { return self.finish() }

        let fileNamePath = NCUtilityFileSystem().getFileNamePath(metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId)
        let fileNamePreviewLocalPath = NCUtilityFileSystem().getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)
        let fileNameIconLocalPath = NCUtilityFileSystem().getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

        var etagResource: String?
        if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
            etagResource = metadata.etagResource
        }
        let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

        NextcloudKit.shared.downloadPreview(
            fileNamePathOrFileId: fileNamePath,
            fileNamePreviewLocalPath: fileNamePreviewLocalPath,
            widthPreview: Int(self.maxWidth) / 2,
            heightPreview: Int(self.maxHeight) / 2,
            fileNameIconLocalPath: fileNameIconLocalPath,
            sizeIcon: NCGlobal.shared.sizeIcon,
            etag: etagResource,
            options: options) { _, _, imageIcon, _, etag, error in
                NCManageDatabase.shared.setMetadataEtagResource(ocId: self.metadata.ocId, etagResource: etag)

                let thumbnail: ScaledThumbnail

                if error == .success, let image = imageIcon {
                    thumbnail = ScaledThumbnail(image: image, metadata: self.metadata)
                    self.cache.setMediaImage(ocId: self.metadata.ocId, etag: self.metadata.etag, image: .actual(image))
                } else {
                    let image = UIImage(systemName: self.metadata.isVideo ? "video.fill" : "photo.fill")!.withRenderingMode(.alwaysTemplate)
                    thumbnail = ScaledThumbnail(image: image, isPlaceholderImage: true, metadata: self.metadata)
                    self.cache.setMediaImage(ocId: self.metadata.ocId, etag: self.metadata.etag, image: .placeholder)
                }

                self.onThumbnailDownloaded(thumbnail)

                self.finish()
            }
    }
}
