//
//  EmojisCollectionViewDelegate.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/30/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

class EmojisCollectionViewDelegate: NSObject, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    var stickersViewControllerDelegate : StickersViewControllerDelegate?

    let emojiRanges = [
        0x1F601...0x1F64F, // emoticons
        0x1F30D...0x1F567, // Other additional symbols
        0x1F680...0x1F6C0, // Transport and map symbols
        0x1F681...0x1F6C5 //Additional transport and map symbols
    ]
    
    var emojis: [String] = []
    
    override init() {
        super.init()
        
        for range in emojiRanges {
            for i in range {
                let c = String(describing: UnicodeScalar(i)!)
                emojis.append(c)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return emojis.count
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emojiLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
        emojiLabel.textAlignment = .center
        emojiLabel.text = emojis[indexPath.item]
        emojiLabel.font = UIFont.systemFont(ofSize: 70)
        stickersViewControllerDelegate?.didSelectView(view: emojiLabel)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell  = collectionView.dequeueReusableCell(withReuseIdentifier: "EmojiCollectionViewCell", for: indexPath) as! EmojiCollectionViewCell
        cell.emojiLabel.text = emojis[indexPath.item]
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}
