//
//  NCAutoUploadFileNamesView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 10/03/24.
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
            // Specify Filename
            Section(header: Text(NSLocalizedString("_mode_filename_", comment: ""))) {
                Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $model.maintainFilename)
                    .font(.system(size: 16))
                    .onChange(of: model.maintainFilename, perform: { newValue in
                        model.toggleMaintainOriginalFilename(newValue: newValue)
                        model.getFileName()
                    })
                // Filename
                if !model.maintainFilename {
                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $model.specifyFilename)
                        .font(.system(size: 16))
                        .onChange(of: model.specifyFilename, perform: { newValue in
                            model.toggleAddFilenameType(newValue: newValue)
                            model.getFileName()
                        })
                }
            }
            .transition(.slide)
            .animation(.easeInOut)
            // Filename Preview
            fileNamePreview
                .animation(.easeInOut)
        }.navigationBarTitle(NSLocalizedString("_mode_filename_", comment: ""))
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
                        .foregroundColor(Color(UIColor.label))
                        .fontWeight(.medium)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                    Spacer()
                    TextField(NSLocalizedString("_filename_header_", comment: ""), text: $model.changedName)
                        .onSubmit {
                            model.submitChangedName()
                        }
                        .onChange(of: model.changedName, perform: { _ in
                            model.getFileName()
                        })

                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.label))
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .multilineTextAlignment(.trailing)
                }
                .font(.system(size: 16))
                Text("\(model.fileName)")
                    .font(.system(size: 16))
            }, header: {
                Text(NSLocalizedString("_filename_", comment: ""))
            }, footer: {
                Text(NSLocalizedString("_preview_filename_footer_", comment: ""))
            })
        } else {
            Section(content: {
                Text(NSLocalizedString("_default_filename_image_", comment: ""))
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
