//
//  LoadableState.swift
//  Nextcloud
//
//  Created by Dhanesh on 09/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

enum LoadableState<T> {
    case idle
    case loading
    case success(T)
    case failure(Error)
}
