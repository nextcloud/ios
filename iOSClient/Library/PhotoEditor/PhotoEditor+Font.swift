//
//  PhotoEditor+Font.swift
//
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit

extension PhotoEditorViewController {
    
    //Resources don't load in main bundle we have to register the font
    func registerFont(){
        let bundle = Bundle(for: PhotoEditorViewController.self)
        let url =  bundle.url(forResource: "icomoon", withExtension: "ttf")
        
        guard let fontDataProvider = CGDataProvider(url: url! as CFURL) else {
            return
        }
        guard let font = CGFont(fontDataProvider) else {return}
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(font, &error) else {
            return
        }
    }
}
