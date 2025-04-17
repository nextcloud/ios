//
//  HiDriveCollectionViewCommonSelectToolbarDelegate.swift
//  Nextcloud
//
//  Created by Sergey Kaliberda on 05.01.2025.
//  Copyright © 2025 Viseven Europe OÜ. All rights reserved.
//


protocol HiDriveCollectionViewCommonSelectToolbarDelegate: AnyObject {
    func selectAll()
    func delete()
    func move()
    func share()
    func recover()
    func saveAsAvailableOffline(isAnyOffline: Bool)
    func lock(isAnyLocked: Bool)
    func toolbarWillAppear()
    func toolbarWillDisappear()
}

extension HiDriveCollectionViewCommonSelectToolbarDelegate {
    func selectAll() { }
    func delete() { }
    func move() { }
    func share() { }
    func recover() { }
    func saveAsAvailableOffline(isAnyOffline: Bool) { }
    func lock(isAnyLocked: Bool) { }
    func toolbarWillAppear() { }
    func toolbarWillDisappear() { }
}
