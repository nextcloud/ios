// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Milen Pivchev
// SPDX-License-Identifier: GPL-3.0-or-later

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
