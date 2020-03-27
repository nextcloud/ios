//
//  NCIntroViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.12.19.
//  Copyright © 2019 Philippe Weidmann. All rights reserved.
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

class NCIntroViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var buttonLogin: UIButton!
    @IBOutlet weak var buttonSignUp: UIButton!
    @IBOutlet weak var buttonHost: UIButton!
    @IBOutlet weak var introCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!

    @objc var delegate: NCIntroViewController?
    private let titles = [Bundle.main.localizedString(forKey: "_intro_1_title_", value: nil, table: "InfomaniakLocalizable"),
                          Bundle.main.localizedString(forKey: "_intro_2_title_", value: nil, table: "InfomaniakLocalizable"),
                          Bundle.main.localizedString(forKey: "_intro_3_title_", value: nil, table: "InfomaniakLocalizable"),
                          Bundle.main.localizedString(forKey: "_intro_4_title_", value: nil, table: "InfomaniakLocalizable")]
    private let images = [UIImage(named: "intro1"), UIImage(named: "intro2"), UIImage(named: "intro3"), UIImage(named: "intro4")]
    private var timerAutoScroll: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = NCBrandColor.sharedInstance.customer
        self.navigationController?.navigationBar.barTintColor = NCBrandColor.sharedInstance.introBackground
                
        if #available(iOS 13.0, *) {
            self.pageControl.currentPageIndicatorTintColor = .systemGray
        } else {
            self.pageControl.currentPageIndicatorTintColor = .darkGray
        }
        
        if #available(iOS 13.0, *) {
            self.pageControl.pageIndicatorTintColor = .systemGray2
        } else {
            self.pageControl.pageIndicatorTintColor = .gray
        }

        self.buttonLogin.layer.cornerRadius = 5
        self.buttonLogin.setTitleColor(.white, for: .normal)
        self.buttonLogin.backgroundColor = NCBrandColor.sharedInstance.customer
        self.buttonLogin.setTitle(NSLocalizedString("_log_in_", comment: ""), for: .normal)

        self.buttonSignUp.isHidden = true

        self.buttonHost.isHidden = true

        self.introCollectionView.register(UINib(nibName: "NCIntroCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "introCell")
        self.introCollectionView.dataSource = self
        self.introCollectionView.delegate = self
        self.introCollectionView.backgroundColor = NCBrandColor.sharedInstance.introBackground
        self.pageControl.numberOfPages = self.titles.count
        self.view.backgroundColor = NCBrandColor.sharedInstance.introBackground
        self.timerAutoScroll = Timer.scheduledTimer(timeInterval: 5, target: self, selector: (#selector(NCIntroViewController.autoScroll)), userInfo: nil, repeats: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timerAutoScroll?.invalidate()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        pageControl.currentPage = 0
        introCollectionView.collectionViewLayout.invalidateLayout()
    }

    @objc func autoScroll() {
        if(pageControl.currentPage + 1 >= titles.count) {
            pageControl.currentPage = 0
        }
        else {
            pageControl.currentPage += 1
        }
        introCollectionView.scrollToItem(at: IndexPath(row: pageControl.currentPage, section: 0), at: .centeredHorizontally, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, targetContentOffsetForProposedContentOffset proposedContentOffset: CGPoint) -> CGPoint {
        return CGPoint.zero
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return titles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "introCell", for: indexPath) as! NCIntroCollectionViewCell
        cell.backgroundColor = .clear
        
        if #available(iOS 13.0, *) {
            cell.titleLabel.textColor = .label
        } else {
            cell.titleLabel.textColor = .black
        }
        cell.titleLabel.text = titles[indexPath.row]
        cell.imageView.image = images[indexPath.row]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timerAutoScroll = Timer.scheduledTimer(timeInterval: 5, target: self, selector: (#selector(NCIntroViewController.autoScroll)), userInfo: nil, repeats: true)
        pageControl.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        timerAutoScroll?.invalidate()
    }

    @IBAction func login(_ sender: Any) {
        (UIApplication.shared.delegate as! AppDelegate).openLoginView(navigationController, selector: Int(k_intro_login), openLoginWeb: false)
    }

    @IBAction func signup(_ sender: Any) {
        (UIApplication.shared.delegate as! AppDelegate).openLoginView(navigationController, selector: Int(k_intro_signup), openLoginWeb: false)
    }

    @IBAction func host(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as? AppDelegate

        let browserWebVC = UIStoryboard(name: "NCBrowserWeb", bundle: nil).instantiateInitialViewController() as? NCBrowserWeb

        browserWebVC?.urlBase = NCBrandOptions.sharedInstance.linkLoginHost

        if let browserWebVC = browserWebVC {
            appDelegate?.window.rootViewController?.present(browserWebVC, animated: true)
        }
    }
}
