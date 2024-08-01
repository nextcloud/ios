//
//  FilesServerUrlsHolder.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 30.07.2024.
//  Copyright © 2024 Viseven Europe OÜ. All rights reserved.
//

import Foundation

class FilesServerUrlsHolder {
    static let filesServerUrl = ThreadSafeDictionary<String, NCFiles>()
}
