//
//  NCIntroViewController.swift
//  Nextcloud
//
//  Created by Philippe Weidmann on 24.12.19.
//  Copyright © 2019 Philippe Weidmann. All rights reserved.
//  Copyright © 2019 Marino Faggiana All rights reserved.
//
//  Author Philippe Weidmann
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

class NCIntroViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    @IBOutlet weak var buttonLogin: UIButton!
    @IBOutlet weak var buttonSignUp: UIButton!
    @IBOutlet weak var buttonHost: UIButton!
    @IBOutlet weak var introCollectionView: UICollectionView!
    @IBOutlet weak var pageControl: UIPageControl!

    weak var delegate: NCIntroViewController?
    /// Controller
    var controller: NCMainTabBarController?

    private let appDelegate = (UIApplication.shared.delegate as? AppDelegate)!
    private let titles = [NSLocalizedString("_intro_1_title_", comment: ""), NSLocalizedString("_intro_2_title_", comment: ""), NSLocalizedString("_intro_3_title_", comment: ""), NSLocalizedString("_intro_4_title_", comment: "")]
    private let images = [UIImage(named: "intro1"), UIImage(named: "intro2"), UIImage(named: "intro3"), UIImage(named: "intro4")]
    private var timer: Timer?
    private var textColor: UIColor = .white
    private var textColorOpponent: UIColor = .black

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let isTooLight = NCBrandColor.shared.customer.isTooLight()
        let isTooDark = NCBrandColor.shared.customer.isTooDark()

        if isTooLight {
            textColor = .black
            textColorOpponent = .white
        } else if isTooDark {
            textColor = .white
            textColorOpponent = .black
        } else {
            textColor = .white
            textColorOpponent = .black
        }

        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithTransparentBackground()
        navBarAppearance.shadowColor = .clear
        navBarAppearance.shadowImage = UIImage()
        self.navigationController?.navigationBar.standardAppearance = navBarAppearance
        self.navigationController?.view.backgroundColor = NCBrandColor.shared.customer
        self.navigationController?.navigationBar.tintColor = textColor

        if !NCManageDatabase.shared.getAllTableAccount().isEmpty {
            let navigationItemCancel = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .done, target: self, action: #selector(self.actionCancel))
            navigationItemCancel.tintColor = textColor
            navigationItem.leftBarButtonItem = navigationItemCancel
        }

        pageControl.currentPageIndicatorTintColor = textColor
        pageControl.pageIndicatorTintColor = .lightGray

        buttonLogin.layer.cornerRadius = 20
        buttonLogin.setTitleColor(NCBrandColor.shared.customer, for: .normal)
        buttonLogin.backgroundColor = textColor
        buttonLogin.setTitle(NSLocalizedString("_log_in_", comment: ""), for: .normal)

        buttonSignUp.layer.cornerRadius = 20
        buttonSignUp.layer.borderColor = textColor.cgColor
        buttonSignUp.layer.borderWidth = 1.0
        buttonSignUp.setTitleColor(textColor, for: .normal)
        buttonSignUp.backgroundColor = NCBrandColor.shared.customer
        buttonSignUp.titleLabel?.adjustsFontSizeToFitWidth = true
        buttonSignUp.titleEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
        buttonSignUp.setTitle(NSLocalizedString("_sign_up_", comment: ""), for: .normal)

        buttonHost.layer.cornerRadius = 20
        buttonHost.setTitle(NSLocalizedString("_host_your_own_server", comment: ""), for: .normal)
        buttonHost.setTitleColor(textColor.withAlphaComponent(0.5), for: .normal)

        introCollectionView.register(UINib(nibName: "NCIntroCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "introCell")
        introCollectionView.dataSource = self
        introCollectionView.delegate = self
        introCollectionView.backgroundColor = NCBrandColor.shared.customer
        pageControl.numberOfPages = self.titles.count

        view.backgroundColor = NCBrandColor.shared.customer

        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { _ in
            self.timer?.invalidate()
            self.timer = nil
        }

        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { _ in
            self.timer = Timer.scheduledTimer(timeInterval: 4, target: self, selector: (#selector(NCIntroViewController.autoScroll)), userInfo: nil, repeats: true)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if traitCollection.userInterfaceStyle == .light {
            return .lightContent
        } else {
            return .darkContent
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        timer?.invalidate()
        timer = nil
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.pageControl?.currentPage = 0
            self.introCollectionView?.collectionViewLayout.invalidateLayout()
        }
    }

    @objc func autoScroll() {
        if pageControl.currentPage + 1 >= titles.count {
            pageControl.currentPage = 0
        } else {
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
        let cell = (collectionView.dequeueReusableCell(withReuseIdentifier: "introCell", for: indexPath) as? NCIntroCollectionViewCell)!
        cell.backgroundColor = NCBrandColor.shared.customer
        cell.indexPath = indexPath
        cell.titleLabel.textColor = textColor
        cell.titleLabel.text = titles[indexPath.row]
        cell.imageView.image = images[indexPath.row]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return collectionView.bounds.size
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: (#selector(NCIntroViewController.autoScroll)), userInfo: nil, repeats: true)
        pageControl.currentPage = Int(scrollView.contentOffset.x) / Int(scrollView.frame.width)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Action

    @objc func actionCancel() {
        dismiss(animated: true) { }
    }

    @IBAction func login(_ sender: Any) {
        if let viewController = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLogin") as? NCLogin {
            viewController.controller = self.controller
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    @IBAction func signupWithProvider(_ sender: Any) {
        if let viewController = UIStoryboard(name: "NCLogin", bundle: nil).instantiateViewController(withIdentifier: "NCLoginProvider") as? NCLoginProvider {
            viewController.controller = self.controller
            viewController.urlBase = NCBrandOptions.shared.linkloginPreferredProviders
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    @IBAction func host(_ sender: Any) {
        guard let url = URL(string: NCBrandOptions.shared.linkLoginHost) else { return }
        UIApplication.shared.open(url)
    }
}

extension UINavigationController {
    open override var childForStatusBarStyle: UIViewController? {
        return topViewController?.childForStatusBarStyle ?? topViewController
    }
}
