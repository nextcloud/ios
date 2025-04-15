//
//  NCUploadScanDocument.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 28/12/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import SwiftUI
import NextcloudKit
import Vision
import VisionKit
import Photos
import PDFKit

class NCUploadScanDocument: ObservableObject {
    internal var metadata = tableMetadata()
    internal var images: [UIImage]
    internal var password: String = ""
    internal var isTextRecognition: Bool = false
    internal var quality: Double = 0
    internal var removeAllFiles: Bool = false
    internal let utilityFileSystem = NCUtilityFileSystem()
    internal let database = NCManageDatabase.shared

    @Published var serverUrl: String
    @Published var showHUD: Bool = false
    @Published var controller: NCMainTabBarController?

    var session: NCSession.Session {
        NCSession.shared.getSession(controller: controller)
    }

    init(images: [UIImage], serverUrl: String, controller: NCMainTabBarController?) {
        self.images = images
        self.serverUrl = serverUrl
        self.controller = controller
    }

    func save(fileName: String, password: String = "", isTextRecognition: Bool = false, removeAllFiles: Bool, quality: Double, completion: @escaping (_ openConflictViewController: Bool, _ error: Bool) -> Void) {
        self.password = password
        self.isTextRecognition = isTextRecognition
        self.quality = quality
        self.removeAllFiles = removeAllFiles

        metadata = self.database.createMetadata(fileName: fileName,
                                                fileNameView: fileName,
                                                ocId: UUID().uuidString,
                                                serverUrl: serverUrl,
                                                url: "",
                                                contentType: "",
                                                session: session,
                                                sceneIdentifier: controller?.sceneIdentifier)

        metadata.session = NCNetworking.shared.sessionUploadBackground
        metadata.sessionSelector = NCGlobal.shared.selectorUploadFile
        metadata.status = NCGlobal.shared.metadataStatusWaitUpload
        metadata.sessionDate = Date()

        if self.database.getMetadataConflict(account: session.account, serverUrl: serverUrl, fileNameView: fileName, nativeFormat: metadata.nativeFormat) != nil {
            completion(true, false)
        } else {
            createPDF(metadata: metadata) { error in
                if !error {
                    completion(false, false)
                }
            }
        }
    }

    func createPDF(metadata: tableMetadata, completion: @escaping (_ error: Bool) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            let fileNamePath = self.utilityFileSystem.getDirectoryProviderStorageOcId(metadata.ocId, fileNameView: metadata.fileNameView)
            let pdfData = NSMutableData()

            if self.password.isEmpty {
                UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
            } else {
                for char in self.password.unicodeScalars {
                    if !char.isASCII {
                        let error = NKError(errorCode: NCGlobal.shared.errorForbidden, errorDescription: "_password_ascii_")
                        NCContentPresenter().showError(error: error)
                        return DispatchQueue.main.async { completion(true) }
                    }
                }
                let info: [AnyHashable: Any] = [kCGPDFContextUserPassword as String: self.password, kCGPDFContextOwnerPassword as String: self.password]
                UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, info)
            }

            for image in self.images {
                self.drawImage(image: image, quality: self.quality, isTextRecognition: self.isTextRecognition, fontColor: UIColor.clear)
            }

            UIGraphicsEndPDFContext()

            do {
                try pdfData.write(to: URL(fileURLWithPath: fileNamePath), options: .atomic)
                metadata.size = self.utilityFileSystem.getFileSize(filePath: fileNamePath)
                NCNetworkingProcess.shared.createProcessUploads(metadatas: [metadata])
                if self.removeAllFiles {
                    let path = self.utilityFileSystem.directoryScan
                    let filePaths = try FileManager.default.contentsOfDirectory(atPath: path)
                    for filePath in filePaths {
                        try FileManager.default.removeItem(atPath: path + "/" + filePath)
                    }
                }
            } catch {
                print("Error: \(error)")
            }

            DispatchQueue.main.async { completion(false) }
        }
    }

    func createPDFPreview(quality: Double, isTextRecognition: Bool, completion: @escaping (_ data: Data) -> Void) {
        DispatchQueue.global(qos: .userInteractive).async {
            if let image = self.images.first {
                let pdfData = NSMutableData()
                UIGraphicsBeginPDFContextToData(pdfData, CGRect.zero, nil)
                self.drawImage(image: image, quality: quality, isTextRecognition: isTextRecognition, fontColor: UIColor.red)
                UIGraphicsEndPDFContext()
                DispatchQueue.main.async { completion(pdfData as Data) }
            } else {
                let url = Bundle.main.url(forResource: "Reasons to use Nextcloud", withExtension: "pdf")!
                let data = try? Data(contentsOf: url)
                DispatchQueue.main.async { completion(data!) }
            }
        }
    }

    func fileName(_ fileName: String) -> String {
        let fileName = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty, fileName != ".", fileName.lowercased() != ".pdf" else { return "" }
        let ext = (fileName as NSString).pathExtension.uppercased()

        if ext.isEmpty {
            return fileName + ".pdf"
        } else {
            return (fileName as NSString).deletingPathExtension + ".pdf"
        }
    }

    private func changeCompressionImage(_ image: UIImage, quality: Double) -> UIImage {
        var compressionQuality: CGFloat = 0.0
        let baseHeight: Float = 595.2    // A4
        let baseWidth: Float = 841.8     // A4

        switch quality {
        case 0:
            compressionQuality = 0.1
        case 1:
            compressionQuality = 0.3
        case 2:
            compressionQuality = 0.5
        case 3:
            compressionQuality = 0.7
        case 4:
            compressionQuality = 0.9
        default:
            break
        }

        var newHeight = Float(image.size.height)
        var newWidth = Float(image.size.width)
        var imgRatio: Float = newWidth / newHeight
        let baseRatio: Float = baseWidth / baseHeight

        if newHeight > baseHeight || newWidth > baseWidth {
            if imgRatio < baseRatio {
                imgRatio = baseHeight / newHeight
                newWidth = imgRatio * newWidth
                newHeight = baseHeight
            } else if imgRatio > baseRatio {
                imgRatio = baseWidth / newWidth
                newHeight = imgRatio * newHeight
                newWidth = baseWidth
            } else {
                newHeight = baseHeight
                newWidth = baseWidth
            }
        }

        let rect = CGRect(x: 0.0, y: 0.0, width: CGFloat(newWidth), height: CGFloat(newHeight))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0)
        image.draw(in: rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        let imageData = img?.jpegData(compressionQuality: CGFloat(compressionQuality))
        UIGraphicsEndImageContext()
        if let imageData = imageData, let image = UIImage(data: imageData) {
            return image
        }
        return image
    }

    private func bestFittingFont(for text: String, in bounds: CGRect, fontDescriptor: UIFontDescriptor, fontColor: UIColor) -> [NSAttributedString.Key: Any] {
        let constrainingDimension = min(bounds.width, bounds.height)
        let properBounds = CGRect(origin: .zero, size: bounds.size)
        var attributes: [NSAttributedString.Key: Any] = [:]
        let infiniteBounds = CGSize(width: CGFloat.infinity, height: CGFloat.infinity)
        var bestFontSize: CGFloat = constrainingDimension

        // Search font (H)
        for fontSize in stride(from: bestFontSize, through: 0, by: -1) {
            let newFont = UIFont(descriptor: fontDescriptor, size: fontSize)
            attributes[.font] = newFont

            let currentFrame = text.boundingRect(with: infiniteBounds, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)

            if properBounds.contains(currentFrame) {
                bestFontSize = fontSize
                break
            }
        }

        // Search kern (W)
        let font = UIFont(descriptor: fontDescriptor, size: bestFontSize)
        attributes = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: fontColor, NSAttributedString.Key.kern: 0] as [NSAttributedString.Key: Any]
        for kern in stride(from: 0, through: 100, by: 0.1) {
            let attributesTmp = [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: fontColor, NSAttributedString.Key.kern: kern] as [NSAttributedString.Key: Any]
            let size = text.size(withAttributes: attributesTmp).width
            if size <= bounds.width {
                attributes = attributesTmp
            } else {
                break
            }
        }

        return attributes
    }

    private func drawImage(image: UIImage, quality: Double, isTextRecognition: Bool, fontColor: UIColor) {
        let image = changeCompressionImage(image, quality: quality)
        let bounds = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)

        if isTextRecognition {

            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            image.draw(in: bounds)

            let requestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])

            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                for observation in observations {
                    guard let textLine = observation.topCandidates(1).first else { continue }

                    var t: CGAffineTransform = CGAffineTransform.identity
                    t = t.scaledBy(x: image.size.width, y: -image.size.height)
                    t = t.translatedBy(x: 0, y: -1)
                    let rect = observation.boundingBox.applying(t)
                    let text = textLine.string

                    let font = UIFont.systemFont(ofSize: rect.size.height, weight: .regular)
                    let attributes = self.bestFittingFont(for: text, in: rect, fontDescriptor: font.fontDescriptor, fontColor: fontColor)

                    text.draw(with: rect, options: .usesLineFragmentOrigin, attributes: attributes, context: nil)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try? requestHandler.perform([request])

        } else {

            UIGraphicsBeginPDFPageWithInfo(bounds, nil)
            image.draw(in: bounds)
        }
    }
}

// MARK: - Delegate

extension NCUploadScanDocument: NCSelectDelegate {
    func dismissSelect(serverUrl: String?, metadata: tableMetadata?, type: String, items: [Any], overwrite: Bool, copy: Bool, move: Bool, session: NCSession.Session) {
        if let serverUrl = serverUrl {
            self.serverUrl = serverUrl
        }
    }
}

extension NCUploadScanDocument: NCCreateFormUploadConflictDelegate {
    func dismissCreateFormUploadConflict(metadatas: [tableMetadata]?) {
        if let metadata = metadatas?.first {
            self.showHUD.toggle()
            createPDF(metadata: metadata) { error in
                if !error {
                    self.showHUD.toggle()
                    NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDismissScanDocument)
                }
            }
        }
    }
}

// MARK: - View

struct UploadScanDocumentView: View {
    @State var fileName = NCUtilityFileSystem().createFileNameDate("scan", ext: "")
    @State var footer = ""
    @State var password: String = ""
    @State var isSecuredPassword: Bool = true
    @State var isTextRecognition: Bool = NCKeychain().textRecognitionStatus
    @State var quality = NCKeychain().qualityScanDocument
    @State var removeAllFiles: Bool = NCKeychain().deleteAllScanImages
    @State var isPresentedSelect = false
    @State var isPresentedUploadConflict = false

    @ObservedObject var model: NCUploadScanDocument

    var metadatasConflict: [tableMetadata] = []

    init(model: NCUploadScanDocument) {
        self.model = model
    }

    func getTextServerUrl(_ serverUrl: String) -> String {
        if let directory = NCManageDatabase.shared.getTableDirectory(predicate: NSPredicate(format: "account == %@ AND serverUrl == %@", model.session.account, serverUrl)), let metadata = NCManageDatabase.shared.getMetadataFromOcId(directory.ocId) {
            return (metadata.fileNameView)
        } else {
            return (serverUrl as NSString).lastPathComponent
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                List {
                    Section(header: Text(NSLocalizedString("_file_creation_", comment: "")), footer: Text(footer)) {
                        HStack {
                            Label {
                                if NCUtilityFileSystem().getHomeServer(session: model.session) == model.serverUrl {
                                    Text("/")
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                } else {
                                    Text(self.getTextServerUrl(model.serverUrl))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            } icon: {
                                Image("folder")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isPresentedSelect = true
                        }
                        .complexModifier { view in
                            if #available(iOS 16, *) {
                                view.alignmentGuide(.listRowSeparatorLeading) { _ in
                                    return 0
                                }
                            }
                        }
                        HStack {
                            Text(NSLocalizedString("_filename_", comment: ""))
                            TextField(NSLocalizedString("_enter_filename_", comment: ""), text: $fileName)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: fileName) { _ in
                                    if let fileNameError = FileNameValidator.checkFileName(fileName, account: self.model.controller?.account) {
                                        footer = fileNameError.errorDescription
                                    } else {
                                        footer = ""
                                    }
                                }
                        }
                        HStack {
                            Group {
                                Text(NSLocalizedString("_password_", comment: ""))
                                if isSecuredPassword {
                                    SecureField(NSLocalizedString("_enter_password_", comment: ""), text: $password)
                                        .multilineTextAlignment(.trailing)
                                } else {
                                    TextField(NSLocalizedString("_enter_password_", comment: ""), text: $password)
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                            Button(action: {
                                isSecuredPassword.toggle()
                            }) {
                                Image(systemName: self.isSecuredPassword ? "eye.slash" : "eye")
                                    .foregroundColor(Color(UIColor.placeholderText))
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        HStack {
                            Toggle(NSLocalizedString("_text_recognition_", comment: ""), isOn: $isTextRecognition)
                                .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.getElement(account: model.session.account))))
                                .onChange(of: isTextRecognition) { newValue in
                                    NCKeychain().textRecognitionStatus = newValue
                                }
                        }
                    }
                    .complexModifier { view in
                        view.listRowSeparator(.hidden)
                    }

                    Section {
                        VStack(spacing: 20) {
                            Toggle(NSLocalizedString("_delete_all_scanned_images_", comment: ""), isOn: $removeAllFiles)
                                .toggleStyle(SwitchToggleStyle(tint: Color(NCBrandColor.shared.getElement(account: model.session.account))))
                                .onChange(of: removeAllFiles) { newValue in
                                    NCKeychain().deleteAllScanImages = newValue
                                }
                            Button(NSLocalizedString("_save_", comment: "")) {
                                let fileName = model.fileName(fileName)
                                if !fileName.isEmpty {
                                    model.showHUD.toggle()
                                    model.save(fileName: fileName, password: password, isTextRecognition: isTextRecognition, removeAllFiles: removeAllFiles, quality: quality) { openConflictViewController, error in
                                        model.showHUD.toggle()
                                        if error {
                                            print("error")
                                        } else if openConflictViewController {
                                            isPresentedUploadConflict = true
                                        } else {
                                            NotificationCenter.default.postOnMainThread(name: NCGlobal.shared.notificationCenterDismissScanDocument)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(ButtonRounded(disabled: fileName.isEmpty || !footer.isEmpty, account: model.session.account))
                            .disabled(fileName.isEmpty || !footer.isEmpty)
                        }
                    }

                    Section(header: Text(NSLocalizedString("_quality_image_title_", comment: ""))) {
                        VStack {
                            Slider(value: $quality, in: 0...4, step: 1, onEditingChanged: { touch in
                                if !touch {
                                    NCKeychain().qualityScanDocument = quality
                                }
                            })
                            .accentColor(Color(NCBrandColor.shared.getElement(account: model.session.account)))
                        }
                        PDFKitRepresentedView(quality: $quality, isTextRecognition: $isTextRecognition, uploadScanDocument: model)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height / 2)
                    }
                    .complexModifier { view in
                        view.listRowSeparator(.hidden)
                    }
                }
                NCHUDView(showHUD: $model.showHUD, textLabel: NSLocalizedString("_wait_", comment: ""), image: "doc.badge.arrow.up", color: NCBrandColor.shared.getElement(account: model.session.account))
                    .offset(y: model.showHUD ? 5 : -200)
                    .animation(.easeOut, value: model.showHUD)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $isPresentedSelect) {
            NCSelectViewControllerRepresentable(delegate: model, session: model.session)
        }
        .sheet(isPresented: $isPresentedUploadConflict) {
            UploadConflictView(delegate: model, serverUrl: model.serverUrl, metadatasUploadInConflict: [model.metadata], metadatasNOConflict: [])
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct PDFKitRepresentedView: UIViewRepresentable {
    typealias UIView = PDFView
    @Binding var quality: Double
    @Binding var isTextRecognition: Bool
    @ObservedObject var uploadScanDocument: NCUploadScanDocument

    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFKitRepresentedView.UIViewType {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
        uploadScanDocument.createPDFPreview(quality: quality, isTextRecognition: isTextRecognition) { data in
            uiView.document = PDFDocument(data: data)
            uiView.document?.page(at: 0)?.annotations.forEach({
                $0.isReadOnly = true
            })
            uiView.autoScales = true
        }
    }
}

// MARK: - Preview

struct UploadScanDocumentView_Previews: PreviewProvider {
    static var previews: some View {
        let model = NCUploadScanDocument(images: [], serverUrl: "ABCD", controller: nil)
        UploadScanDocumentView(model: model)
    }
}
