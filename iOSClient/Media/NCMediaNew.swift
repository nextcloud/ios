//
//  NCMediaNew.swift
//  Nextcloud
//
//  Created by Milen on 25.08.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots
import NextcloudKit
import FlowGrid

class NCMediaUIHostingController: UIHostingController<NCMediaNew> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCMediaNew())
    }
}

// extension Array {
//    func chunked(into size: Int) -> [[Element]] {
//        return stride(from: 0, to: count, by: size).map {
//            Array(self[$0 ..< Swift.min($0 + size, count)])
//        }
//    }
// }

struct MinHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct NCMediaNew: View {
    @StateObject private var viewModel = NCMediaViewModel()

    @State private var gridColumns = Array(repeating: GridItem(.flexible(minimum: 50)), count: 2)

    @State private var minHeight: CGFloat = 0

    var body: some View {
        //            StaggeredGrid(list: viewModel.metadatas, columns: 2, content: { metadata in
        //                MediaCellView(metadata: metadata)
        //            })
        //            FlowGrid(items: viewModel.metadatas, rowHeight: 200) { metadata in
        //                MediaCellView(metadata: metadata)
        //            }
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.metadatas.chunked(into: 2), id: \.self) { rowMetadatas in

                        MediaRow(metadatas: rowMetadatas)
                    }
                }
            }
        }
    }
}

//    var body: some View {
//        Grid(0..<viewModel.metadatas.count, tracks: [.fit, .fit]) { width in
//            AsyncImage(url: URL(string: "https://picsum.photos/id/237/536/354")) { image in
//                image
////                    .resizable()
////                    .scaledToFill()
//            } placeholder: {
//                ProgressView()
//            }
////            .frame(width: CGFloat.random(in: 20...200), height: 50)
//            .frame(maxWidth: 65 * CGFloat(width))
//        }
//    }
// }

struct MediaRow: View {
    let metadatas: [tableMetadata]
    @StateObject private var viewModel = MediaCellViewModel()

    var body: some View {
        HStack(spacing: 0) {
            if viewModel.thumbnails.isEmpty {
                ProgressView()
            } else {
                ForEach(viewModel.thumbnails, id: \.self) { thumbnail in
                    let _ = print(viewModel.thumbnails)
                    MediaCellView(shrinkRatio: viewModel.shrinkRatio, thumbnail: thumbnail)
                    // get image here using async await and pass it to the MediaCellView
    //                MediaCellView(shrinkRatio: viewModel.getSize(), metadata: metadata)
                }
            }
        }
        .onAppear {
            viewModel.configure(metadatas: metadatas)
            viewModel.downloadThumbnails()
        }
    }
}

struct MediaCellView: View {
    let shrinkRatio: CGFloat
    let thumbnail: UIImage
//    let metadata: tableMetadata
//    @StateObject private var viewModel = MediaCellViewModel()

    var body: some View {
        Image(uiImage: thumbnail)
            .resizable()
//            .scaledToFill()
            .frame(width: CGFloat(thumbnail.size.width * shrinkRatio), height: CGFloat(thumbnail.size.height * shrinkRatio))

//        let wtf = CGFloat(metadata.width) * shrinkRatio
//        let _ = print(viewModel.thumbnail.size.width)
//        let _ = print(viewModel.thumbnail.size.height)
    }
}

@MainActor class MediaCellViewModel: ObservableObject {
    @Published private(set) var thumbnails: [UIImage] = []
    private var metadatas: [tableMetadata] = []
    var shrinkRatio: CGFloat = 0

    func configure(metadatas: [tableMetadata]) {
        self.metadatas = metadatas
    }

    func downloadThumbnails() {
        var thumbnails: [UIImage] = []

        metadatas.enumerated().forEach { index, metadata in
            let thumbnailPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

            if let thumbnailPath, FileManager.default.fileExists(atPath: thumbnailPath) {
                // Load thumbnail from file
                if let image = UIImage(contentsOfFile: thumbnailPath) {
                    thumbnails.append(image)

                    if thumbnails.count == self.metadatas.count {
                        self.thumbnails = thumbnails
                        shrinkRatio = getSize(rowMetadatas: thumbnails, fullWidth: UIScreen.main.bounds.width)
                    }
                }
            } else {
                let fileNamePath = CCUtility.returnFileNamePath(fromFileName: metadata.fileName, serverUrl: metadata.serverUrl, urlBase: metadata.urlBase, userId: metadata.userId, account: metadata.account)!
                let fileNamePreviewLocalPath = CCUtility.getDirectoryProviderStoragePreviewOcId(metadata.ocId, etag: metadata.etag)!
                let fileNameIconLocalPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)!

                var etagResource: String?
                if FileManager.default.fileExists(atPath: fileNameIconLocalPath) && FileManager.default.fileExists(atPath: fileNamePreviewLocalPath) {
                    etagResource = metadata.etagResource
                }
                let options = NKRequestOptions(queue: NextcloudKit.shared.nkCommonInstance.backgroundQueue)

                NextcloudKit.shared.downloadPreview(
                    fileNamePathOrFileId: fileNamePath,
                    fileNamePreviewLocalPath: fileNamePreviewLocalPath,
                    widthPreview: Int(UIScreen.main.bounds.width) / 2,
                    heightPreview: Int(UIScreen.main.bounds.height) / 2,
                    fileNameIconLocalPath: fileNameIconLocalPath,
                    sizeIcon: NCGlobal.shared.sizeIcon,
                    etag: etagResource,
                    options: options) { _, _, imageIcon, _, etag, error in

                        if error == .success, let image = imageIcon {
                            NCManageDatabase.shared.setMetadataEtagResource(ocId: metadata.ocId, etagResource: etag)
                            DispatchQueue.main.async {
    //                            if self.metadata.ocId == self.cell?.fileObjectId, let filePreviewImageView = self.cell?.filePreviewImageView {
    //                                UIView.transition(with: filePreviewImageView,
    //                                                  duration: 0.75,
    //                                                  options: .transitionCrossDissolve,
    //                                                  animations: { filePreviewImageView.image = imageIcon },
    //                                                  completion: nil)
                                thumbnails.append(image)
    //                            } else {
    //                                if self.view is UICollectionView {
    //                                    (self.view as? UICollectionView)?.reloadData()
    //                                } else if self.view is UITableView {
    //                                    (self.view as? UITableView)?.reloadData()
    //                                }
    //                            }

//                                self.metadata.height = Int(self.thumbnail.size.height)
//                                self.metadata.width = Int(self.thumbnail.size.width)
//                                print(self.thumbnail.size.width)
//                                print(self.thumbnail.size.height)
//                                NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDownloadedThumbnail, userInfo: ["ocId": self.metadata.ocId])

                                print("------------")
                                print(thumbnails.count)

                                if thumbnails.count == self.metadatas.count {
                                    self.thumbnails = thumbnails
                                    self.shrinkRatio = self.getSize(rowMetadatas: thumbnails, fullWidth: UIScreen.main.bounds.width)
                                }
                            }


                        }
    //                    self.finish()
                    }
            }
        }

    }

    func getSize(rowMetadatas: [UIImage], fullWidth: CGFloat) -> CGFloat {
        var newSummedWidth: CGFloat = 0
        let maxHeight = rowMetadatas.compactMap { CGFloat($0.size.height) }.max() ?? 0
        for metadata in rowMetadatas {
            let height1 = metadata.size.height
            let width1 = metadata.size.width

            let scaleFactor1 = maxHeight / height1
//            let newHeight1 = height1 * scaleFactor1
            let newWidth1 = width1 * scaleFactor1

            newSummedWidth += CGFloat(newWidth1)
        }

        let shrinkRatio: CGFloat = fullWidth / newSummedWidth

        return shrinkRatio
    }
}

@MainActor class NCMediaViewModel: ObservableObject {
    @Published var metadatas: [tableMetadata] = []

    private var account: String = ""
    private var lastContentOffsetY: CGFloat = 0
    private var mediaPath = ""
    private var livePhoto: Bool = false
    private var predicateDefault: NSPredicate?
    private var predicate: NSPredicate?
    private let appDelegate = UIApplication.shared.delegate as? AppDelegate
    internal var filterClassTypeImage = false
    internal var filterClassTypeVideo = false

    init() {
        reloadDataSourceWithCompletion { _ in }
    }

    @objc func reloadDataSourceWithCompletion(_ completion: @escaping (_ metadatas: [tableMetadata]) -> Void) {
        guard let appDelegate, !appDelegate.account.isEmpty else { return }

        if account != appDelegate.account {
            self.metadatas = []
            account = appDelegate.account
//            DispatchQueue.main.async { self.collectionView?.reloadData() }
        }

//        DispatchQueue.global().async {
            self.queryDB(isForced: true)
//            DispatchQueue.main.sync {
//                self.reloadDataThenPerform {
//                    self.updateMediaControlVisibility()
//                    self.mediaCommandTitle()
//                    completion(self.metadatas)
//                }
//            }
//        }
    }

    func queryDB(isForced: Bool = false) {
        guard let appDelegate else { return }

        livePhoto = CCUtility.getLivePhoto()

        if let activeAccount = NCManageDatabase.shared.getActiveAccount() {
            self.mediaPath = activeAccount.mediaPath
        }

        let startServerUrl = NCUtilityFileSystem.shared.getHomeServer(urlBase: appDelegate.urlBase, userId: appDelegate.userId) + mediaPath

        predicateDefault = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND (classFile == %@ OR classFile == %@) AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue, NKCommon.TypeClassFile.video.rawValue)

        if filterClassTypeImage {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.video.rawValue)
        } else if filterClassTypeVideo {
            predicate = NSPredicate(format: "account == %@ AND serverUrl BEGINSWITH %@ AND classFile == %@ AND NOT (session CONTAINS[c] 'upload')", appDelegate.account, startServerUrl, NKCommon.TypeClassFile.image.rawValue)
        } else {
            predicate = predicateDefault
        }

        guard let predicate = predicate else { return }

        metadatas = NCManageDatabase.shared.getMetadatasMedia(predicate: predicate, livePhoto: self.livePhoto)

        switch CCUtility.getMediaSortDate() {
        case "date":
            self.metadatas = self.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)})
        case "creationDate":
            self.metadatas = self.metadatas.sorted(by: {($0.creationDate as Date) > ($1.creationDate as Date)})
        case "uploadDate":
            self.metadatas = self.metadatas.sorted(by: {($0.uploadDate as Date) > ($1.uploadDate as Date)})
        default:
            break
        }
    }

//    func getSmallestHeight(rowMetadatas: [tableMetadata], metadata: tableMetadata) -> CGFloat {
////        let scaleFactor = (rowMetadatas.compactMap { $0.height }.max() ?? 0) / metadata.height
//
//        var newSummedWidth: CGFloat = 0
//
//        for metadata in rowMetadatas {
//            let height1 = CGFloat(metadata.height == 0 ? 336 : metadata.height)
//            let width1 = CGFloat(metadata.width == 0 ? 336 : metadata.width)
//
//            let scaleFactor1 = (rowMetadatas.compactMap { CGFloat($0.height) }.max() ?? 0) / height1
//            let newHeight1 = height1 * scaleFactor1
//            let newWidth1 = width1 * scaleFactor1
//
//            newSummedWidth += CGFloat(newWidth1)
//        }
//
//        return CGFloat(metadata.height * scaleFactor)
//    }
}

struct NCMediaNew_Previews: PreviewProvider {
    static var previews: some View {
        snapshots.previews.previewLayout(.sizeThatFits)
    }

    static var snapshots: PreviewSnapshots<String> {
        PreviewSnapshots(
            configurations: [
                .init(name: NCGlobal.shared.defaultSnapshotConfiguration, state: "")
            ],
            configure: { _ in
                NCMediaNew()
            })
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
