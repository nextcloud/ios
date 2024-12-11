// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct NCTermOfServiceModelView: View {
    @State private var selectedLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
    @State private var termsText = "Loading terms..."
    @ObservedObject var model: NCTermOfServiceModel

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            HStack {
                Text(NSLocalizedString("_terms_of_service_", comment: "Terms of Service"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Select Language", selection: $selectedLanguage) {
                    ForEach(model.languages.keys.sorted(), id: \.self) { key in
                        Text(model.languages[key] ?? "").tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onChange(of: selectedLanguage) { newLanguage in
                    if let terms = model.terms[newLanguage] {
                        termsText = terms
                    } else {
                        selectedLanguage = model.languages.first?.key ?? "en"
                        termsText = model.terms[selectedLanguage] ?? "Terms not available in selected language."
                    }
                }
            }
            .padding(.horizontal)

            ScrollView {
                Text(termsText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
            }
            .padding(.top)

            Button(action: {
                model.signTermsOfService(termId: model.termsId[selectedLanguage])
            }) {
                Text(model.hasUserSigned ? NSLocalizedString("_terms_accepted_", comment: "Accepted terms") : NSLocalizedString("_terms_accept_", comment: "Accept terms"))
                    .foregroundColor(.white)
                    .padding()
                    .background(model.hasUserSigned ? Color.green : Color.blue)
                    .cornerRadius(10)
                    .padding(.bottom)
            }
            .disabled(model.hasUserSigned)
        }
        .padding()
        .onAppear {
            if let item = model.terms[selectedLanguage] {
                termsText = item
            } else {
                selectedLanguage = model.languages.first?.key ?? "en"
                termsText = model.terms[selectedLanguage] ?? "Terms not available in selected language."
            }
        }
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}

#Preview {
    NCTermOfServiceModelView(model: NCTermOfServiceModel(controller: nil, tos: nil))
}
