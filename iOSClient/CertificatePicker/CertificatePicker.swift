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
                    }
                }
            }
            .onAppear {
                model.delegate = delegate
            }
            .navigationTitle("_cert_navigation_title_")
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
            .alert("_client_cert_wrong_password_", isPresented: $model.isWrongPassword) {}
        }
    }
}

protocol CertificatePickerDelegate: AnyObject {
    func certificatePickerDidImportIdentity(_ picker: CertificatePickerModel, for urlBase: String)
}

@Observable class CertificatePickerModel: NSObject, UIDocumentPickerDelegate {
    var isWrongPassword = false
    @ObservationIgnored weak var delegate: CertificatePickerDelegate?

    func handleCertificate(fileUrl: URL, urlBase: String, password: String) {
        if fileUrl.startAccessingSecurityScopedResource() {
            defer {
                fileUrl.stopAccessingSecurityScopedResource()
            }

            if let identity = getIdentityFromP12(from: fileUrl, password: password) {
                let urlWithoutScheme = urlBase.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                let label = "client_identity_\(urlWithoutScheme)"
                storeIdentityInKeychain(identity: identity, label: label)
                delegate?.certificatePickerDidImportIdentity(self, for: urlBase)
            } else {
                isWrongPassword = true
            }
        }
    }

    func getIdentityFromP12(from url: URL, password: String) -> SecIdentity? {
        guard let p12Data = try? Data(contentsOf: url) else { return nil }

        let options = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        if status == errSecSuccess,
           let array = items as? [[String: Any]] {
            // swiftlint:disable force_cast
            if let identity = array.first?[kSecImportItemIdentity as String] as! SecIdentity? {
                // swiftlint:enable force_cast
                return identity
            }
        }
        return nil
    }

    func storeIdentityInKeychain(identity: SecIdentity, label: String) {
        let addQuery: [String: Any] = [
            kSecValueRef as String: identity,
            kSecClass as String: kSecClassIdentity,
            kSecAttrLabel as String: label,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let classes = [kSecClassIdentity, kSecClassCertificate, kSecClassKey]
        for secClass in classes {
            let deleteQuery: [String: Any] = [
                kSecClass as String: secClass,
                kSecAttrLabel as String: label,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            let status = SecItemDelete(deleteQuery as CFDictionary)
            print("Deleting \(secClass): \(status)")
        }

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        print("Add status: \(addStatus)")

    }

}

#Preview {
    CertificatePicker(urlBase: "test.com")
}

