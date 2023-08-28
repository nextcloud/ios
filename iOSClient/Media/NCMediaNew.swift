//
//  NCMediaNew.swift
//  Nextcloud
//
//  Created by Milen on 25.08.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import SwiftUI
import PreviewSnapshots
import ExyteGrid
import NextcloudKit

class NCMediaUIHostingController: UIHostingController<NCMediaNew> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NCMediaNew())
    }
}

struct NCMediaNew: View {
    @StateObject private var viewModel = NCMediaViewModel()

    @State private var gridColumns = Array(repeating: GridItem(.flexible(minimum: 50, maximum: .infinity)), count: 2)

    var body: some View {
        VStack {
            ScrollView {
                LazyVGrid(columns: gridColumns, alignment: .leading) {
                    ForEach(viewModel.metadatas, id: \.self) { metadata in
//                        GeometryReader { geo in
                            MediaCellView(metadata: metadata)
//                                .frame(width: CGFloat.random(in: 20...200), height: 50)
//                        }
//                        .cornerRadius(8.0)
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
}

struct MediaCellView: View {
    let metadata: tableMetadata
    @StateObject private var viewModel = MediaCellViewModel()

    var body: some View {
        Image(uiImage: viewModel.thumbnail)
            .onAppear {
                viewModel.downloadThumbnail(metadata: metadata)
            }
//            .scaledToFit()
            .frame(width: 50, height: 50)
            .aspectRatio(1, contentMode: .fit)
            .background(Color.purple)
//            .redacted(reason: viewModel.thumbnail == nil ? .placeholder : [])
    }
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

@MainActor class MediaCellViewModel: ObservableObject {
    @Published var thumbnail: UIImage = UIImage()

    func downloadThumbnail(metadata: tableMetadata) {
        let thumbnailPath = CCUtility.getDirectoryProviderStorageIconOcId(metadata.ocId, etag: metadata.etag)

        if let thumbnailPath, FileManager.default.fileExists(atPath: thumbnailPath) {
            // Load thumbnail from file
            if let image = UIImage(contentsOfFile: thumbnailPath) {
                thumbnail = image
            }
        } else {
            thumbnail = UIImage(systemName: "plus")!
//            // Perform thumbnail download
//            NCOperationQueue.shared.downloadThumbnail(metadata: metadata) { downloadedImage in
//                self.thumbnail = downloadedImage
//            }
        }
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
            self.metadatas = self.metadatas.sorted(by: {($0.date as Date) > ($1.date as Date)} )
        case "creationDate":
            self.metadatas = self.metadatas.sorted(by: {($0.creationDate as Date) > ($1.creationDate as Date)} )
        case "uploadDate":
            self.metadatas = self.metadatas.sorted(by: {($0.uploadDate as Date) > ($1.uploadDate as Date)} )
        default:
            break
        }
    }
}
