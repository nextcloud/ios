import SwiftUI

struct NCTermOfServiceModelView: View {
    // Proprietà per il titolo, la lingua selezionata, i termini e lo stato di accettazione
    @State private var selectedLanguage = "en"
    @State private var acceptedTerms = false
    @State private var termsText = "Loading terms..."

    // Esempio di lingue e termini (modifica con dati reali)
    let languages = ["en": "English", "de": "Deutsch", "it": "Italiano"]
    let terms = [
        "en": "These are the Terms of Service in English. These are the Terms of Service in English. These are the Terms of Service in English. e poi ciao",
        "de": "Dies sind die Allgemeinen Geschäftsbedingungen auf Deutsch.",
        "it": "Questi sono i Termini di Servizio in Italiano."
    ]

    var body: some View {
        VStack {
            // HStack per il titolo a sinistra e il menu a tendina a destra
            HStack {
                Text("Terms of Service")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Picker("Select Language", selection: $selectedLanguage) {
                    ForEach(languages.keys.sorted(), id: \.self) { key in
                        Text(languages[key] ?? "").tag(key)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .onChange(of: selectedLanguage) { newLanguage in
                    // Cambia i termini in base alla lingua selezionata
                    termsText = terms[newLanguage] ?? "Terms not available in selected language."
                }
            }
            .padding(.horizontal) // Padding orizzontale solo per l'HStack

            // ScrollView per i termini con scrollbar
            ScrollView {
                Text(termsText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal) // Solo per il testo dei termini
            }
            .padding(.top) // Aggiunge un po' di spazio sopra il testo dei termini

            // Bottone per accettare i termini
            Button(action: {
                acceptedTerms.toggle()
            }) {
                Text(acceptedTerms ? "Terms Accepted" : "Accept Terms")
                    .foregroundColor(.white)
                    .padding()
                    .background(acceptedTerms ? Color.green : Color.blue)
                    .cornerRadius(10)
                    .padding(.bottom)
            }
            .disabled(acceptedTerms) // Disabilita il bottone se già accettato
        }
        .padding() // Padding globale
        .onAppear {
            // Carica i termini per la lingua predefinita
            termsText = terms[selectedLanguage] ?? "Terms not available in selected language."
        }
    }
}

#Preview {
    NCTermOfServiceModelView()
    // NCAccountSettingsView(model: NCAccountSettingsModel(controller: nil, delegate: nil))
}




/*
struct NCTermOfServiceModelView: View {
    @ObservedObject var model: NCTermOfServiceModel

    @State private var isExpanded: Bool = false
    @State private var showUserStatus = false
    @State private var showServerCertificate = false
    @State private var showPushCertificate = false
    @State private var showDeleteAccountAlert: Bool = false
    @State private var showAddAccount: Bool = false
    @State private var animation: Bool = false

    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(content: {
                    TabView(selection: $model.indexActiveAccount) {
                        ForEach(0..<model.tblAccounts.count, id: \.self) { index in
                            let status = model.getUserStatus()
                            let avatar = NCUtility().loadUserImage(for: model.tblAccounts[index].user, displayName: model.tblAccounts[index].displayName, urlBase: model.tblAccounts[index].urlBase)
                            ///
                            /// User
                            VStack {
                                Image(uiImage: avatar)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: UIScreen.main.bounds.width, height: 75)
                                if let statusImage = status.statusImage {
                                    ZStack {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 30, height: 30)
                                        Image(uiImage: statusImage)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 30, height: 30)
                                    }
                                    .offset(x: 30, y: -30)
                                }
                                Text(model.getUserName())
                                    .font(.subheadline)
                                Spacer()
                                    .frame(height: 10)
                                Text(status.statusMessage)
                                    .font(.caption)
                                Spacer()
                                    .frame(height: 20)
                                ///
                                /// Personal data
                                if let tblAccount = model.tblAccount {
                                    if !tblAccount.email.isEmpty {
                                        HStack {
                                            Image(systemName: "mail")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.email)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.phone.isEmpty {
                                        HStack {
                                            Image(systemName: "phone")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.phone)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                    if !tblAccount.address.isEmpty {
                                        HStack {
                                            Image(systemName: "house")
                                                .resizable()
                                                .scaledToFit()
                                                .font(Font.system(.body).weight(.light))
                                                .frame(width: 20, height: 20)
                                            Text(tblAccount.address)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: 30)
                                    }
                                }
                            }
                        }
                    }
                    .font(.subheadline)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .frame(height: model.getTableViewHeight())
                    .animation(.easeIn(duration: 0.3), value: animation)
                    .onChange(of: model.indexActiveAccount) { index in
                        animation.toggle()
                        model.setAccount(account: model.tblAccounts[index].account)
                    }
                    ///
                    /// Change alias
                    VStack {
                        HStack {
                            Text(NSLocalizedString("_alias_", comment: "") + ":")
                                .fontWeight(.medium)
                            Spacer()
                            TextField(NSLocalizedString("_alias_placeholder_", comment: ""), text: $model.alias)
                                .font(.callout)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: model.alias) { newValue in
                                    model.setAlias(newValue)
                                }
                        }
                        Text(NSLocalizedString("_alias_footer_", comment: ""))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(Color(UIColor.lightGray))
                    }
                    ///
                    /// User Status
                    if NCCapabilities.shared.getCapabilities(account: model.tblAccount?.account).capabilityUserStatusEnabled {
                        Button(action: {
                            showUserStatus = true
                        }, label: {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_set_user_status_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.subheadline)
                        })
                        .sheet(isPresented: $showUserStatus) {
                            if let account = model.tblAccount?.account {
                                UserStatusView(showUserStatus: $showUserStatus, account: account)
                            }
                        }
                        .onChange(of: showUserStatus) { _ in }
                    }
                    ///
                    /// Certificate server
                    if model.isAdminGroup() {
                        Button(action: {
                            showServerCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.subheadline)
                        })
                        .sheet(isPresented: $showServerCertificate) {
                            if let url = URL(string: model.tblAccount?.urlBase), let host = url.host {
                                certificateDetailsView(host: host, title: NSLocalizedString("_certificate_view_", comment: ""))
                            }
                        }
                        ///
                        /// Certificate push
                        Button(action: {
                            showPushCertificate.toggle()
                        }, label: {
                            HStack {
                                Image(systemName: "lock")
                                    .resizable()
                                    .scaledToFit()
                                    .font(Font.system(.body).weight(.light))
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
                                Text(NSLocalizedString("_certificate_pn_details_", comment: ""))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(Color(NCBrandColor.shared.textColor))
                                    .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                            }
                            .font(.subheadline)
                        })
                        .sheet(isPresented: $showPushCertificate) {
                            if let url = URL(string: NCBrandOptions.shared.pushNotificationServerProxy), let host = url.host {
                                certificateDetailsView(host: host, title: NSLocalizedString("_certificate_pn_view_", comment: ""))
                            }
                        }
                    }
                })
                ///
                /// Delete account
                Section(content: {
                    Button(action: {
                        showDeleteAccountAlert.toggle()
                    }, label: {
                        HStack {
                            Image(systemName: "trash")
                                .resizable()
                                .scaledToFit()
                                .font(Font.system(.body).weight(.light))
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.red)
                            Text(NSLocalizedString("_remove_local_account_", comment: ""))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.red)
                                .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 20))
                        }
                        .font(.callout)
                    })
                    .alert(NSLocalizedString("_want_delete_account_", comment: ""), isPresented: $showDeleteAccountAlert) {
                        Button(NSLocalizedString("_remove_local_account_", comment: ""), role: .destructive) {
                            model.deleteAccount()
                        }
                        Button(NSLocalizedString("_cancel_", comment: ""), role: .cancel) { }
                    }
                })
            }
            .navigationBarTitle(NSLocalizedString("_account_settings_", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(Font.system(.body).weight(.light))
                    .foregroundStyle(Color(NCBrandColor.shared.iconImageColor))
            })
        }
        .defaultViewModifier(model)
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(model.$dismissView) { newValue in
            if newValue {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onDisappear {
           
        }
    }
}
*/

#Preview {
    NCAccountSettingsView(model: NCAccountSettingsModel(controller: nil, delegate: nil))
}
