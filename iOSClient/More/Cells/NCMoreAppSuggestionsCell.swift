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

        talkView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(talkTapped)))
        notesView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(notesTapped)))
        moreAppsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(moreAppsTapped)))
    }

    @objc func talkTapped() {
        let url = URL(string: "nextcloudtalk://")!

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(URL(string: "https://apps.apple.com/de/app/nextcloud-talk/id1296825574")!)
        }
    }

    @objc func notesTapped() {
        let url = URL(string: "nextcloudnotes://")!

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            UIApplication.shared.open(URL(string: "https://apps.apple.com/de/app/nextcloud-notes/id813973264")!)
        }
    }

    @objc func moreAppsTapped() {
        UIApplication.shared.open(URL(string: "https://www.apple.com/us/search/nextcloud?src=globalnav")!)
    }
}
