//
//  NCViewerPDFSearch.swift
//  Nextcloud
//
//  Created by Marino Faggiana on 23/03/2020.
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
import PDFKit

@objc protocol NCViewerPDFSearchDelegate: AnyObject {
    func searchPdfSelection(_ pdfSelection: PDFSelection)
}

class NCViewerPDFSearch: UITableViewController, UISearchBarDelegate, PDFDocumentDelegate {

    var searchBar = UISearchBar()
    var pdfDocument: PDFDocument?
    var searchResultArray: [PDFSelection] = []

    weak var delegate: NCViewerPDFSearchDelegate?

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        searchBar.delegate = self
        searchBar.sizeToFit()
        searchBar.searchBarStyle = .minimal

        navigationItem.titleView = searchBar

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UINib(nibName: "NCViewerPDFSearchCell", bundle: nil), forCellReuseIdentifier: "Cell")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchBar.becomeFirstResponder()
    }

    // MARK: - UITableView DataSource / Delegate

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 82
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.searchResultArray.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! NCViewerPDFSearchCell
        let pdfSelection = searchResultArray[indexPath.row] as PDFSelection

        // if let pdfOutline = pdfDocument?.outlineItem(for: pdfSelection) {
        //    cell.outlineLabel.text = pdfOutline.label
        // }

        let pdfPage = pdfSelection.pages.first
        let pageNumber = pdfPage?.pageRef?.pageNumber ?? 0
        cell.pageNumberLabel.text = NSLocalizedString("_scan_document_pdf_page_", comment: "") + ": " + String(pageNumber)

        let extendSelection = pdfSelection.copy() as! PDFSelection
        extendSelection.extend(atStart: 10)
        extendSelection.extend(atEnd: 90)
        extendSelection.extendForLineBoundaries()

        let nsRange = NSString(string: extendSelection.string!).range(of: pdfSelection.string!, options: String.CompareOptions.caseInsensitive)
        if nsRange.location != NSNotFound {
            let attributedSubString = NSAttributedString(string: NSString(string: extendSelection.string!).substring(with: nsRange), attributes: [NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 17), NSAttributedString.Key.foregroundColor : UIColor.systemBlue])
            let attributedString = NSMutableAttributedString(string: extendSelection.string!)
            attributedString.replaceCharacters(in: nsRange, with: attributedSubString)
            cell.searchResultTextLabel.attributedText = attributedString
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let pdfSelection = searchResultArray[indexPath.row]
        delegate?.searchPdfSelection(pdfSelection)
        dismiss(animated: true)
    }

    // MARK: - PDFSelection Delegate

    func didMatchString(_ instance: PDFSelection) {
        searchResultArray.append(instance)
        tableView.reloadData()
    }

    // MARK: - UIScrollView Delegate

    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }

    // MARK: - UISearchBarDelegate

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        pdfDocument?.cancelFindString()
        navigationItem.setRightBarButton(nil, animated: false)
        dismiss(animated: true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.count < 2 { return }

        searchResultArray.removeAll()
        tableView.reloadData()
        pdfDocument?.cancelFindString()
        pdfDocument?.delegate = self
        pdfDocument?.beginFindString(searchText, withOptions: .caseInsensitive)
    }

    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {

        let cancelBarButtonItem = UIBarButtonItem(title: NSLocalizedString("_cancel_", comment: ""), style: .plain, target: self, action: #selector(cancelBarButtonItemClicked))
        navigationItem.setRightBarButton(cancelBarButtonItem, animated: true)
        return true
    }

    @objc func cancelBarButtonItemClicked() {
        searchBarCancelButtonClicked(searchBar)
    }
}

class NCViewerPDFSearchCell: UITableViewCell {

    @IBOutlet weak var outlineLabel: UILabel!
    @IBOutlet weak var pageNumberLabel: UILabel!
    @IBOutlet weak var searchResultTextLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    }
}
