//
//  NCMenuPanelController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 23.01.20.
//  Copyright © 2020 Philippe Weidmann. All rights reserved.
//  Copyright © 2020 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann <philippe.weidmann@infomaniak.com>
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

import FloatingPanel

class NCMenuPanelController: FloatingPanelController {

    var parentPresenter: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 13.0, *) {
            self.surfaceView.backgroundColor = .systemBackground
        }
        self.isRemovalInteractionEnabled = true
        if #available(iOS 11, *) {
            self.surfaceView.cornerRadius = 16
        } else {
            self.surfaceView.cornerRadius = 0
        }
    }

}
