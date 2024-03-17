//
//  AutoUploadFileNamesView.swift
//  Nextcloud
//
//  Created by Aditya Tyagi on 10/03/24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import SwiftUI

struct AutoUploadFileNamesView<ViewModel: AutoUploadFileNamesViewModel>: View {
    @ObservedObject var viewModel: ViewModel

    var body: some View {
        Form {
            // Maintain Original Filename
            Section(content: {
                
            }, header: {
                
            }, footer: {
                Text("You can choose to keep the original name of your files, add a type to the filename, or specify a custom filename. This can help you stay organized and quickly identify your files.")
                    .font(.system(size: 12))
                    .multilineTextAlignment(.leading)
            })
            
            // Specify Filename
            Section(header: Text(NSLocalizedString("_filename_", comment: ""))) {
                Toggle(NSLocalizedString("_maintain_original_filename_", comment: ""), isOn: $viewModel.maintainFilename)
                    .onChange(of: viewModel.maintainFilename, perform: { newValue in
                        viewModel.toggleMaintainOriginalFilename(newValue: newValue)
                    })
                
                
                // Filename
                if !viewModel.maintainFilename {
                    Toggle(NSLocalizedString("_add_filenametype_", comment: ""), isOn: $viewModel.specifyFilename)
                        .onChange(of: viewModel.specifyFilename, perform: { newValue in
                            viewModel.toggleAddFilenameType(newValue: newValue)
                        })
                }
            }
            .transition(.slide)
            .animation(.easeInOut)
            
            
            // Filename Preview
            if !viewModel.maintainFilename {
                Section(content: {
                    HStack {
                        Text(NSLocalizedString("_filename_", comment: ""))
                            .font(.system(size: 17))
                            .foregroundColor(Color(UIColor.label))
                            .fontWeight(.medium)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                        Spacer()
                        TextField("FILENAME", text: $viewModel.changedName)
                            .onSubmit {
                                viewModel.submitChangedName()
                            }
                            .font(.system(size: 15))
                            .foregroundColor(Color(UIColor.label))
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Text("\(viewModel.previewFileName())")
                }, header: {
                    Text("CUSTOM FILENAME")
                }, footer: {
                    Text("Example preview of filename. You can use the mask MM, MMM, DD, Y Y,YYYY and HH,hh, mm,ss, ampm for date/time:")
                })
            } else {
                Section(content: {
                    Text("Filename: IMG_0001.JPG")
                }, header: {
                    Text("FILENAME")
                }, footer: {
                    Text("Example preview of filename: IMG_0001.JPG")
                })
            }
        }.navigationBarTitle("Filename Mode")
            .padding(.top, 0)
            .transition(.slide)
        
        
    }
}

#Preview {
    AutoUploadFileNamesView(viewModel: AutoUploadFileNamesViewModel())
}
