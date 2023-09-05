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

struct MinHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct NCMediaNew: View {
    @StateObject private var viewModel = NCMediaViewModel()

//    @State private var gridColumns = Array(repeating: GridItem(.flexible(minimum: 50)), count: 5)

    @State private var minHeight: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading) {
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

struct RowData {
    var scaledThumbnails: [ScaledThumbnail] = []
    var shrinkRatio: CGFloat = 0
}

struct ScaledThumbnail: Hashable {
    let image: UIImage
    var scaledSize: CGSize = .zero
    let metadata: tableMetadata

    func hash(into hasher: inout Hasher) {
        hasher.combine(image)
    }
}

struct MediaRow: View {
    let metadatas: [tableMetadata]
    @StateObject private var viewModel = MediaCellViewModel()

    var body: some View {
        HStack() {
            if viewModel.rowData.scaledThumbnails.isEmpty {
                ProgressView()
            } else {
                ForEach(viewModel.rowData.scaledThumbnails, id: \.self) { thumbnail in
                    MediaCellView(thumbnail: thumbnail, shrinkRatio: viewModel.rowData.shrinkRatio)
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
    let thumbnail: ScaledThumbnail
    let shrinkRatio: CGFloat
//    let thumbnail: UIImage
//    let metadata: tableMetadata
//    @StateObject private var viewModel = MediaCellViewModel()

    var body: some View {
        Image(uiImage: thumbnail.image)
            .resizable()
//            .scaledToFill()
            .frame(width: CGFloat(thumbnail.scaledSize.width * shrinkRatio), height: CGFloat(thumbnail.scaledSize.height * shrinkRatio))

//        let wtf = CGFloat(metadata.width) * shrinkRatio
//        let _ = print(viewModel.thumbnail.size.width)
//        let _ = print(viewModel.thumbnail.size.height)
    }
}

@MainActor class MediaCellViewModel: ObservableObject {
//    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var rowData = RowData()

    private var metadatas: [tableMetadata] = []
//    var shrinkRatio: CGFloat = 0

    func configure(metadatas: [tableMetadata]) {
        self.metadatas = metadatas
    }

    func downloadThumbnails() {
        var thumbnails: [ScaledThumbnail] = []

        metadatas.enumerated().forEach { index, metadata in
            let thumbnailPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

            if let thumbnailPath, FileManager.default.fileExists(atPath: thumbnailPath) {
                // Load thumbnail from file
                if let image = UIImage(contentsOfFile: thumbnailPath) {
                    thumbnails.append(ScaledThumbnail(image: image, metadata: metadata))

                    if thumbnails.count == self.metadatas.count {
                        thumbnails.enumerated().forEach { index, thumbnail in
                            thumbnails[index].scaledSize = getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
                        }

                        let shrinkRatio = getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: UIScreen.main.bounds.width)

                        rowData.scaledThumbnails = thumbnails
                        rowData.shrinkRatio = shrinkRatio
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
                                thumbnails.append(ScaledThumbnail(image: image, metadata: metadata))

                                if thumbnails.count == self.metadatas.count {
                                    thumbnails.enumerated().forEach { index, thumbnail in
                                        thumbnails[index].scaledSize = self.getScaledThumbnailSize(of: thumbnail, thumbnailsInRow: thumbnails)
                                    }

                                    let shrinkRatio = self.getShrinkRatio(thumbnailsInRow: thumbnails, fullWidth: 1000)

                                    self.rowData.scaledThumbnails = thumbnails
                                    self.rowData.shrinkRatio = shrinkRatio
                                }
                            }
                        }
                    }
            }
        }

    }

    func getScaledThumbnailSize(of thumbnail: ScaledThumbnail, thumbnailsInRow thumbnails: [ScaledThumbnail]) -> CGSize {
        let maxHeight = thumbnails.compactMap { CGFloat($0.image.size.height) }.max() ?? 0

        let height = thumbnail.image.size.height
        let width = thumbnail.image.size.width

        let scaleFactor = maxHeight / height
        let newHeight = height * scaleFactor
        let newWidth = width * scaleFactor

        return .init(width: newWidth, height: newHeight)
    }

    func getShrinkRatio(thumbnailsInRow thumbnails: [ScaledThumbnail], fullWidth: CGFloat) -> CGFloat {
        var newSummedWidth: CGFloat = 0

        for thumbnail in thumbnails {
            newSummedWidth += CGFloat(thumbnail.scaledSize.width)
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
