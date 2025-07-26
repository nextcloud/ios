// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Aditya Tyagi
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Returns a WebView preferably for Sheets in SwiftUI, using a UIViewRepresentable struct with WebKit library
///
/// - Parameters:
///   - showText: A Bool value which initiates the RTF file view in the sheet
///   - text: A String value which contains the text of RTF file
///   - browserTitle: A String value to show as the title of the webView
struct NCAcknowledgementsView: View {
    @State private var text = ""
    @State var showText: Bool = false
    var browserTitle: String
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(alignment: .center) {
                    Text(browserTitle)
                        .font(.title3)
                        .foregroundColor(Color(NCBrandColor.shared.textColor))
                        .padding(.leading, 8)
                }
                .padding()
                Spacer()
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    ZStack {
                        Image(systemName: "xmark")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .font(Font.system(.body).weight(.light))
                            .frame(width: 14, height: 14)
                            .foregroundColor(Color(NCBrandColor.shared.iconImageColor))
                    }
                }
                .padding()
            }
            Divider()
            if showText {
                ScrollView {
                    Text(text)
                        .padding()
                }
            }
        }
        .navigationBarTitle(Text(NSLocalizedString("_autoupload_description_", comment: "")), displayMode: .inline)
        .onAppear {
            loadRTF()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showText = true
            }
        }
    }
    func loadRTF() {
        if let rtfPath = Bundle.main.url(forResource: "Acknowledgements", withExtension: "rtf"),
           let attributedStringWithRtf = try? NSAttributedString(url: rtfPath, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
            self.text = attributedStringWithRtf.string
        }
    }
}
