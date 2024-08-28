//
//  NCViewCertificateDetails.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 01/06/21.
//  Copyright © 2021 Marino Faggiana. All rights reserved.
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
import SwiftUI

public protocol NCViewCertificateDetailsDelegate: AnyObject {
    func viewCertificateDetailsDismiss(host: String)
}

// optional func
public extension NCViewCertificateDetailsDelegate {
    func viewCertificateDetailsDismiss(host: String) {}
}

class NCViewCertificateDetails: UIViewController {

    @IBOutlet weak var buttonCancel: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var textView: UITextView!

    var delegate: NCViewCertificateDetailsDelegate?
    let utilityFileSystem = NCUtilityFileSystem()

    public var host: String = ""
    public var fileNamePath: String = ""
    public var certificateTitle = NSLocalizedString("_certificate_view_", comment: "")

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.navigationBar.tintColor = NCBrandColor.shared.iconImageColor
        navigationItem.title = certificateTitle
        buttonCancel.title = NSLocalizedString("_close_", comment: "")

        if fileNamePath.isEmpty {
            fileNamePath = utilityFileSystem.directoryCertificates + "/" + host + ".txt"
        }

        if FileManager.default.fileExists(atPath: fileNamePath) {
            do {
                let text = try String(contentsOfFile: fileNamePath, encoding: .utf8)
                let font = UIFont.systemFont(ofSize: 13)
                let attributes = [NSAttributedString.Key.font: font] as [NSAttributedString.Key: Any]
                var contentRect = NSString(string: text).boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 0), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: attributes, context: nil)
                contentRect = CGRect(x: contentRect.origin.x, y: contentRect.origin.y, width: ceil(contentRect.size.width), height: ceil(contentRect.size.height))
                var contentWidth = contentRect.size.width
                if contentWidth < view.frame.size.width {
                    contentWidth = view.frame.size.width
                }
                var contentHeight = contentRect.size.height
                if contentHeight < view.frame.size.height {
                    contentHeight = view.frame.size.width
                }

                textView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
                textView.font = font
                textView.text = text

                scrollView.contentSize = contentRect.size
                scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)

            } catch {
                print("error")
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.delegate?.viewCertificateDetailsDismiss(host: host)
    }

    // MARK: ACTION

    @IBAction func actionCancel(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIViewControllerRepresentable

struct certificateDetailsView: UIViewControllerRepresentable {
    typealias UIViewControllerType = UINavigationController
    var host: String = ""
    var title: String = ""

    func makeUIViewController(context: Context) -> UINavigationController {
        let storyboard = UIStoryboard(name: "NCViewCertificateDetails", bundle: nil)
        let navigationController = storyboard.instantiateInitialViewController() as? UINavigationController
        let viewController = navigationController?.topViewController as? NCViewCertificateDetails

        viewController?.host = host
        viewController?.certificateTitle = title

        return navigationController!
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }
}
