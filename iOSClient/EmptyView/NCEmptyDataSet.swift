//
//  NCEmptyDataSet.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 19/10/2020.
//  Copyright © 2020 Marino Faggiana. All rights reserved.
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

import UIKit

public protocol NCEmptyDataSetDelegate: AnyObject {
    func emptyDataSetView(_ view: NCEmptyView)
}

// optional func
public extension NCEmptyDataSetDelegate {
    func emptyDataSetView(_ view: NCEmptyView) {}
}

class NCEmptyDataSet: NSObject {

    private var emptyView: NCEmptyView?
    private var timer: Timer?
    private var numberItemsForSections: Int = 0
    private weak var delegate: NCEmptyDataSetDelegate?

    private var fillBackgroundName: String = ""
    private var fillBackgroundView = UIImageView()

    private var centerXAnchor: NSLayoutConstraint?
    private var centerYAnchor: NSLayoutConstraint?


    init(view: UIView, offset: CGFloat = 0, delegate: NCEmptyDataSetDelegate?) {
        super.init()

        if let emptyView = UINib(nibName: "NCEmptyView", bundle: nil).instantiate(withOwner: self, options: nil).first as? NCEmptyView {

            self.delegate = delegate
            self.emptyView = emptyView

            emptyView.isHidden = true
            emptyView.translatesAutoresizingMaskIntoConstraints = false

//            emptyView.backgroundColor = .red
//            emptyView.isHidden = false

            emptyView.emptyTitle.sizeToFit()
            emptyView.emptyDescription.sizeToFit()

            view.addSubview(emptyView)

            emptyView.widthAnchor.constraint(equalToConstant: 350).isActive = true
            emptyView.heightAnchor.constraint(equalToConstant: 250).isActive = true

            if let view = view.superview {
                centerXAnchor = emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
                centerYAnchor = emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: offset)
            } else {
                centerXAnchor = emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
                centerYAnchor = emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: offset)
            }

            centerXAnchor?.isActive = true
            centerYAnchor?.isActive = true
        }
    }

    func setOffset(_ offset: CGFloat) {

        centerYAnchor?.constant = offset
    }

    func numberOfItemsInSection(_ num: Int, section: Int) {

        if section == 0 {
            numberItemsForSections = num
        } else {
            numberItemsForSections += num
        }

        if let emptyView = emptyView {

            self.delegate?.emptyDataSetView(emptyView)

            if !(timer?.isValid ?? false) && emptyView.isHidden == true {
                timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerHandler(_:)), userInfo: nil, repeats: false)
            }

            if numberItemsForSections > 0 {
                self.emptyView?.isHidden = true
            }
        }
    }

    @objc func timerHandler(_ timer: Timer) {

        if numberItemsForSections == 0 {
            self.emptyView?.isHidden = false
        } else {
            self.emptyView?.isHidden = true
        }
    }
}

public class NCEmptyView: UIView {

    @IBOutlet weak var emptyImage: UIImageView!
    @IBOutlet weak var emptyTitle: UILabel!
    @IBOutlet weak var emptyDescription: UILabel!

    public override func awakeFromNib() {
        super.awakeFromNib()

        emptyTitle.textColor = .label
    }
}
