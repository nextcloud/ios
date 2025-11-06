// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2025 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

protocol CertificatePickerDelegate: AnyObject {
    func certificatePickerDidImportIdentity(_ picker: CertificatePickerModel, for urlBase: String)
}

@Observable class CertificatePickerModel: NSObject, UIDocumentPickerDelegate {
    var isWrongPassword = false
    var isCertImportedSuccessfully = false
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
                isCertImportedSuccessfully = true
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
