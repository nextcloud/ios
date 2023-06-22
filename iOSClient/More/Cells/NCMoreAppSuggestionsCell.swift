//
//  NCMoreAppSuggestionsCell.swift
//  Nextcloud
//
//  Created by Milen on 14.06.23.
//  Copyright © 2023 Marino Faggiana. All rights reserved.
//

import Foundation

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
        let url = URL(string: "nextcloudtalk://")!

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(URL(string: NCGlobal.shared.talkAppStoreUrl)!)
        }
    }

    @objc func notesTapped() {
        let url = URL(string: "nextcloudnotes://")!

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(URL(string: NCGlobal.shared.notesAppStoreUrl)!)
        }
    }

    @objc func moreAppsTapped() {
        UIApplication.shared.open(URL(string: NCGlobal.shared.moreAppsUrl)!)
    }
}
