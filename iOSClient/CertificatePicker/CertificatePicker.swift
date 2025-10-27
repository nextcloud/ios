// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import UniformTypeIdentifiers

struct CertificatePicker: View {
    @State private var model = CertificatePickerModel()
    @State private var showingPicker = false
    @State private var fileName: String = ""
    @State private var pickedURL: URL? 
    @State private var password: String = ""

    let urlBase: String
    weak var delegate: CertificatePickerDelegate?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section(header: Text(String(format: NSLocalizedString("_no_client_cert_found_", comment: ""), urlBase)), footer: Text("_no_client_cert_found_desc_")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("_cert_title_")
                                    .font(.headline)
                                if !fileName.isEmpty {
                                    Text(fileName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                } else {
                                    Text("No file selected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("_upload_") {
                                showingPicker = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundStyle(Color(NCBrandColor.shared.customer))
                        }
                    }

                    Section(footer: Text("_no_client_cert_found_desc_password_")) {
                        SecureField("_password_", text: $password)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.done)
                            .onSubmit {
                                if let url = pickedURL {
                                    model.handleCertificate(fileUrl: url, urlBase: urlBase, password: password)
                                }
                            }
                    }
                }
            }
            .onAppear {
                model.delegate = delegate
            }
            .navigationTitle(NSLocalizedString("_cert_navigation_title_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                        Button {
                            if let url = pickedURL {
                                model.handleCertificate(fileUrl: url, urlBase: urlBase, password: password)
                            }
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .keyboardShortcut(.defaultAction)
                        .disabled(pickedURL == nil || password.isEmpty)
                        .tint(Color(NCBrandColor.shared.customer))
                }
            }
            .sheet(isPresented: $showingPicker) {
                DocumentPicker(contentTypes: [UTType.pkcs12]) { urls in
                    if let url = urls.first {
                        pickedURL = url
                        fileName = url.lastPathComponent
                    }
                }
            }
            .alert(NSLocalizedString("_client_cert_wrong_password_", comment: ""), isPresented: $model.isWrongPassword) {}
            .onChange(of: model.isCertImportedSuccessfully) { _, newValue in
                if newValue { dismiss() }
            }
        }
    }
}

#Preview {
    CertificatePicker(urlBase: "test.com")
}
