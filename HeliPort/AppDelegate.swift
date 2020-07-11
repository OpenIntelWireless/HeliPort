//
//  AppDelegate.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/3/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        checkDriver()

        let statusBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateOff")
        statusBar.button?.image?.isTemplate = true
        statusBar.menu = StatusMenu()

        StatusBarIcon.statusBar = statusBar
    }

    private func checkDriver() {
        var drv_info = ioctl_driver_info()
        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)

        let version = String(cString: &drv_info.driver_version.0)
        let interface = String(cString: &drv_info.bsd_name.0)
        guard !version.isEmpty, !interface.isEmpty else {
            Log.error("itlwm kext not loaded!")
            return
        }

        Log.debug("Loaded itlwm \(version) as \(interface)")
    }
}
