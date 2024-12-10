import SwiftUI

struct NCTermOfServiceModelView: View {
    @State private var selectedLanguage = "en"
    @State private var acceptedTerms = false
    @State private var termsText = "Loading terms..."
    @ObservedObject var model: NCTermOfServiceModel

    var body: some View {
        VStack {
            HStack {
                Text("Terms of Service")
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
                    // Cambia i termini in base alla lingua selezionata
                    termsText = model.terms[newLanguage] ?? "Terms not available in selected language."
                }
            }
            .padding(.horizontal)

            ScrollView {
                Text(termsText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal) // Solo per il testo dei termini
            }
            .padding(.top)

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
            .disabled(acceptedTerms)
        }
        .padding()
        .onAppear {
            termsText = model.terms[selectedLanguage] ?? "Terms not available in selected language."
        }
    }
}

#Preview {
    NCTermOfServiceModelView(model: NCTermOfServiceModel(controller: nil, tos: nil))
}
