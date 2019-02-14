//
//  ColorsCollectionViewDelegate.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 5/1/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

class ColorsCollectionViewDelegate: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    var colorDelegate : ColorDelegate?
    
    /**
     Array of Colors that will show while drawing or typing
     */
    var colors = [UIColor.black,
                  UIColor.darkGray,
                  UIColor.gray,
                  UIColor.lightGray,
                  UIColor.white,
                  UIColor.blue,
                  UIColor.green,
                  UIColor.red,
                  UIColor.yellow,
                  UIColor.orange,
                  UIColor.purple,
                  UIColor.cyan,
                  UIColor.brown,
                  UIColor.magenta]
    
    override init() {
        super.init()
    }
    
    var stickersViewControllerDelegate : StickersViewControllerDelegate?
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colors.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        colorDelegate?.didSelectColor(color: colors[indexPath.item])
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: "ColorCollectionViewCell", for: indexPath) as! ColorCollectionViewCell
        cell.colorView.backgroundColor = colors[indexPath.item]
        return cell
    }
    
}
