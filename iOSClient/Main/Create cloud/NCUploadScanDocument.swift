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

// MARK: - Preview / Test

struct NCUploadScanDocumentTest: View {

    @State private var currentValue = 1.0

    var body: some View {

        VStack {
            List {
                Section(header: Text(NSLocalizedString("_save_path_", comment: ""))) {
                    HStack {
                        Label {
                            Text("/")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } icon: {
                            Image("folder")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: NCBrandSettings.shared.settingsSizeImage, height: NCBrandSettings.shared.settingsSizeImage)
                                .foregroundColor(Color(NCBrandColor.shared.brand))
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        //
                    }
                }

                Section(header: Text(NSLocalizedString("_quality_image_title_", comment: ""))) {
                    VStack {
                        Text("Current slider value")
                        Slider(value: $currentValue, in: 0...3, step: 1) { didChange in
                            //
                        }
                        .accentColor(Color(NCBrandColor.shared.brand))
                    }
                }

                Section(header: Text(NSLocalizedString("_preview_", comment: ""))) {
                    let fileUrl = Bundle.main.url(forResource: "Reasons to use Nextcloud", withExtension: "pdf")!
                    PDFKitRepresentedView(fileUrl)
                        .frame(width: .infinity, height: 200)
                }
            }
        }
    }
}

struct PDFKitRepresentedView: UIViewRepresentable {

    let url: URL
    init(_ url: URL) {
        self.url = url
    }

    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFKitRepresentedView.UIViewType {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateUIView(_ uiView: UIView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {

    }
}

struct NCUploadScanDocument_Previews: PreviewProvider {
    static var previews: some View {
        // let account = (UIApplication.shared.delegate as! AppDelegate).account
        NCUploadScanDocumentTest()
    }
}
