//
//  NCMoreAppSuggestionsCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation
import SafariServices

class NCMoreAppSuggestionsCell: BaseNCMoreCell {
    @IBOutlet weak var talkView: UIStackView!
    @IBOutlet weak var notesView: UIStackView!
    @IBOutlet weak var moreAppsView: UIStackView!

    static let reuseIdentifier = "NCMoreAppSuggestionsCell"

    static func fromNib() -> UINib {
        return UINib(nibName: "NCMoreAppSuggestionsCell", bundle: nil)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        backgroundColor = .clear

        talkView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(talkTapped)))
        notesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(notesTapped)))
        moreAppsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(moreAppsTapped)))
    }

    @objc func talkTapped() {
        guard let url = URL(string: NCGlobal.shared.talkSchemeUrl) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            guard let url = URL(string: NCGlobal.shared.talkAppStoreUrl) else { return }
            UIApplication.shared.open(url)
        }
    }

    @objc func notesTapped() {
        guard let url = URL(string: NCGlobal.shared.notesSchemeUrl) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            guard let url = URL(string: NCGlobal.shared.notesAppStoreUrl) else { return }
            UIApplication.shared.open(url)
        }
    }

    @objc func moreAppsTapped() {
        guard let url = URL(string: NCGlobal.shared.moreAppsUrl) else { return }
        UIApplication.shared.open(url)
    }
}
