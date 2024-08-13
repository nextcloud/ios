//
//  NCAcknowledgementsView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 04/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//
//  Author Aditya Tyagi <adityagi02@yahoo.com>
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
