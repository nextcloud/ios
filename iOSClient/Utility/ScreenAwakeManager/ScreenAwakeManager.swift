//
//  ScreenAwakeManager.swift
//  Nextcloud
//
//  Created by Milen Pivchev on 18.09.24.
//  Copyright © 2024 Marino Faggiana. All rights reserved.
//

// Modified from https://github.com/ochococo/Insomnia
import UIKit

class ScreenAwakeManager {
    static let shared: ScreenAwakeManager = {
        let instance = ScreenAwakeManager()
        return instance
    }()

    /**
         This mode will change the behavior:

         - `disabled`: Nothing will change (disabled functionality).
         - `always`: Your iOS device will never timeout and lock.
         - `whenCharging`: Device will stay active as long as it's connected to charger.

     */
    var mode: AwakeMode = .off {
        didSet {
            updateMode()
        }
    }

    private unowned let device = UIDevice.current
    private unowned let notificationCenter = NotificationCenter.default
    private unowned let application = UIApplication.shared

    private init() {}

    private func startMonitoring() {
        device.isBatteryMonitoringEnabled = true
        notificationCenter.addObserver(self,
                                       selector: #selector(batteryStateDidChange),
                                       name: UIDevice.batteryStateDidChangeNotification, object: nil)
    }

    private func stopMonitoring() {
        notificationCenter.removeObserver(self)
        device.isBatteryMonitoringEnabled = false
    }

    @objc private func batteryStateDidChange(notification: NSNotification) {
        updateMode()
    }

    private func updateMode() {
        DispatchQueue.main.async { [self] in
            switch mode {
            case .whileCharging:
                startMonitoring()
                application.isIdleTimerDisabled = isPlugged
            case .on:
                stopMonitoring()
                application.isIdleTimerDisabled = true
            case .off:
                stopMonitoring()
                application.isIdleTimerDisabled = false
            }
        }
    }

    private var isPlugged: Bool {
        switch device.batteryState {
        case .unknown, .unplugged:
            return false
        default:
            return true
        }
    }

    deinit {
        stopMonitoring()
        application.isIdleTimerDisabled = false
    }
}
