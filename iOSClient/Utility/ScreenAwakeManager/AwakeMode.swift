//
//  AwakeMode.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 18.09.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

import Foundation

/**
  Modes:

  - `disabled`: Nothing will change (disabled functionality).
  - `always`:  Device will never timeout and lock.
  - `whenCharging`: Device will stay active as long as it's connected to charger.

  */
 enum AwakeMode: CaseIterable, Identifiable {
     /**
     Nothing will change (disabled functionality).
      */
     case off
     /**
     Device will never timeout and lock.
      */
     case on
     /**
     Device will stay active as long as it's connected to charger.
      */
     case whileCharging

     var id: Self { self }
 }
