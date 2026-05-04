//
//  AlbumsManager.swift
//  Nextcloud
//
//  Created by Dhanesh on 09/09/25.
//  Copyright © 2025 Marino Faggiana. All rights reserved.
//

import Foundation
import Combine
import NextcloudKit

final class AlbumsManager {
    
    static let shared = AlbumsManager()
    
    private var account: String = ""
    
    // Albums publisher - Central
    private let albumsSubject = CurrentValueSubject<LoadableState<[Album]>, Never>(.idle)
    var albumsPublisher: AnyPublisher<LoadableState<[Album]>, Never> {
        albumsSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    // MARK: - Public Methods
    func setAccount(_ acc: String) {
        self.account = acc
    }
    
    func syncAlbums(
        optionalActionOnSuccess: (([Album]) -> Void)? = nil
    ) {
        
        albumsSubject.send(.loading)
        
        NextcloudKit.shared.fetchAllAlbums(for: account) { [weak self] result in
            
            switch result {
            case .success(let albumDTOs):
                let albums = albumDTOs.toAlbums()
                self?.albumsSubject.send(.success(albums))
                optionalActionOnSuccess?(albums)
                
            case .failure(let error):
                let nkError = NKError(error: error)
                self?.albumsSubject.send(.failure(nkError))
            }
        }
    }
}
