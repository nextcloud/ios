//
//  NCAutoUploadFileNamesView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 10/03/24.
//  Created by Marino Faggiana on 30/05/24.
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

struct NCAutoUploadFileNamesView: View {
    @ObservedObject var model = NCAutoUploadFileNamesModel()

    var body: some View {
        Form {
            /// Specify Filename
            Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {
                Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $model.maintainFilename)
                    .font(.system(size: 16))
                    .tint(Color(NCBrandColor.shared.brandElement))
                    .onChange(of: model.maintainFilename, perform: { newValue in
                        model.toggleMaintainOriginalFilename(newValue: newValue)
                        model.getFileName()
                    })
                /// Filename
                if !model.maintainFilename {
                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $model.specifyFilename)
                        .font(.system(size: 16))
                        .tint(Color(NCBrandColor.shared.brandElement))
                        .onChange(of: model.specifyFilename, perform: { newValue in
                            model.toggleAddFilenameType(newValue: newValue)
                            model.getFileName()
                        })
                }
            }
            .transition(.slide)
            .animation(.easeInOut, value: model.maintainFilename)

            /// Filename Preview
            fileNamePreview
                .animation(.easeInOut, value: model.specifyFilename)
        }
        .navigationBarTitle(NSLocalizedString("_mode_filename_", comment: ""))
        .defaultViewModifier(model)
        .padding(.top, 0)
        .transition(.slide)
    }

    @ViewBuilder
    var fileNamePreview: some View {
        if !model.maintainFilename {
            Section(content: {
                HStack {
                    Text(NSLocalizedString("_filename_", comment: ""))
                        .font(.system(size: 17))
                        .fontWeight(.medium)
                    Spacer()
                    TextField(NSLocalizedString("_filename_header_", comment: ""), text: $model.changedName)
                        .onChange(of: model.changedName, perform: { _ in
                            model.submitChangedName()
                            model.getFileName()
                        })
                        .font(.system(size: 15))
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 16))
                Text("\(model.fileName)")
                    .font(.system(size: 16))
                    .foregroundColor(Color(UIColor.lightGray))
            }, header: {
                Text(NSLocalizedString("_filename_", comment: ""))
            }, footer: {
                Text(String(format: NSLocalizedString("_preview_filename_", comment: ""), "MM, MMM, DD, YY, YYYY, HH, hh, mm, ss, ampm"))
            })
        } else {
            Section(content: {
                Text("IMG_0001.JPG")
                    .foregroundColor(Color(UIColor.lightGray))
            }, header: {
                Text(NSLocalizedString("_filename_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_default_preview_filename_footer_", comment: ""))
            })
        }

    }
}

#Preview {
    NCAutoUploadFileNamesView(model: NCAutoUploadFileNamesModel())
}
