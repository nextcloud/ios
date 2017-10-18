//
//  Data+CKBitArray.swift
//  CKMnemonic
//
//  Created by 仇弘扬 on 2017/7/25.
//  Copyright © 2017年 askcoin. All rights reserved.
//

import Foundation
import CryptoSwift

public extension UInt8 {
	public func ck_bits() -> [String] {
		let totalBitsCount = MemoryLayout<UInt8>.size * 8
		
		var bitsArray = [String](repeating: "0", count: totalBitsCount)
		
		for j in 0 ..< totalBitsCount {
			let bitVal: UInt8 = 1 << UInt8(totalBitsCount - 1 - j)
			let check = self & bitVal
			
			if (check != 0) {
				bitsArray[j] = "1"
			}
		}
		return bitsArray
	}
}

public extension Data {
	public func ck_toBitArray() -> [String] {
		var toReturn = [String]()
		for num: UInt8 in bytes {
			
			toReturn.append(contentsOf: num.ck_bits())
		}
		return toReturn
	}
}
