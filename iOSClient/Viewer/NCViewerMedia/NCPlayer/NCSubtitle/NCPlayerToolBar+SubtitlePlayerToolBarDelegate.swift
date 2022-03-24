//
//  NCPlayerToolBar+SubtitlePlayerToolBarDelegate.swift
//  Nextcloud
//
//  Created by Federico Malagoni on 11/03/22.
//  Copyright © 2022 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation

protocol SubtitlePlayerToolBarDelegate: AnyObject {
    func subtitleIconTapped()
    func changeSubtitleIconTo(visible: Bool)
    func showIconSubtitle()
}

extension NCPlayerToolBar: SubtitlePlayerToolBarDelegate {

    func subtitleIconTapped() {

        self.ncplayer?.hideOrShowSubtitle()
    }

    func changeSubtitleIconTo(visible: Bool) {

        let color: UIColor = visible ? .white : .lightGray
        self.subtitleButton.setImage(NCUtility.shared.loadImage(named: "captions.bubble", color: color), for: .normal)
    }

    func showIconSubtitle() {

        self.subtitleButton.isEnabled = true
        self.subtitleButton.isHidden = false
    }

    func hideIconSubtitle() {

        self.subtitleButton.isEnabled = false
        self.subtitleButton.isHidden = true
    }
}
