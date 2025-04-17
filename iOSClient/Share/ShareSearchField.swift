//
//  ShareSearchField.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 06.03.2025.
//  Copyright © 2025 STRATO GmbH. All rights reserved.
//

import SwiftUI
import Combine

struct ShareSearchField: View {
    class Model: ObservableObject {
        @Published var placeholder: String = ""
        @Published var text: String = ""
    }
    
    @ObservedObject var model: Model
    let onContactButtonTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            Image(.Share.magnifyingGlass)
                .padding(.leading, 16)
                .padding(.trailing, 11)
            if #available(iOS 16.0, *) {
                TextField("",
                          text: $model.text,
                          prompt: Text(model.placeholder).foregroundColor(Color(.Share.Advanced.SearchField.placeholder)))
                .font(.system(size: 16))
                .autocorrectionDisabled()
            } else {
                ZStack(alignment: .leading) {
                    if model.text.isEmpty {
                        Text(model.placeholder).foregroundColor(Color(.Share.Advanced.SearchField.placeholder))
                    }
                    TextField("", text: $model.text)
                }
                .font(.system(size: 16))
                .autocorrectionDisabled()
            }
            Button {
                onContactButtonTap()
            } label: {
                Image(.Share.userContacts)
            }
            .padding(.leading, 11)
            .padding(.trailing, 12)
        }
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.Share.Advanced.SearchField.border),
                        lineWidth: 1)
        )
    }
}

#Preview {
    ShareSearchField(model: ShareSearchField.Model(),
                     onContactButtonTap: {})
    .padding(10)
    .background(Color(.AppBackground.main))
    .environment(\.colorScheme, .light)
    ShareSearchField(model: ShareSearchField.Model(),
                     onContactButtonTap: {})
    .padding(10)
    .background(Color(.AppBackground.main))
    .environment(\.colorScheme, .dark)
}

class ShareSearchFieldHost: UIHostingController<ShareSearchField> {
    
    private var cancellables: [AnyCancellable] = []
    private var model: ShareSearchField.Model!
    
    override init(rootView: ShareSearchField) {
        super.init(rootView: rootView)
    }
    
    var placeholder: String {
        get {
            return model.placeholder
        }
        set(newValue) {
            model.placeholder = newValue
        }
    }
    
    var text: String {
        get {
            return model.text
        }
        set(newValue) {
            model.text = newValue
        }
    }
    
    convenience init(onSearchTextChanged: @escaping ((_ text: String) -> Void),
                     onContactButtonTap: @escaping (() -> Void)) {
        let model = ShareSearchField.Model()
        let shareSearch = ShareSearchField(model: model,
                                           onContactButtonTap: onContactButtonTap)
        self.init(rootView: shareSearch)
        self.view.backgroundColor = .clear
        self.model = model
        
        self.model
            .$text
            .throttle(for: 0.5,
                      scheduler: DispatchQueue.main,
                      latest: true)
            .removeDuplicates()
            .sink { text in
                onSearchTextChanged(text)
            }.store(in: &cancellables)
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
