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
        checkAPI()

        let statusBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateOff")
        statusBar.button?.image?.isTemplate = true
        statusBar.menu = StatusMenu()

        StatusBarIcon.statusBar = statusBar
    }

    private var drv_info = ioctl_driver_info()

    private func checkDriver() -> Bool {

        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)

        let version = String(cString: &drv_info.driver_version.0)
        let interface = String(cString: &drv_info.bsd_name.0)
        guard !version.isEmpty, !interface.isEmpty else {
            Log.error("itlwm kext not loaded!")
            return false
        }

        Log.debug("Loaded itlwm \(version) as \(interface)")

        return true
    }

    private func checkAPI() {

        // It's fine for users to bypass this check by launching HeliPort first then loading itlwm in terminal
        // Only advanced users do so, and they know what they are doing
        guard checkDriver(), IOCTL_VERSION != drv_info.version else {
            return
        }

        let verAlert = NSAlert()
        verAlert.alertStyle = .critical
        verAlert.messageText = NSLocalizedString("itlwm Version Mismatch", comment: "")
        verAlert.informativeText =
            NSLocalizedString("HeliPort API Version: ", comment: "") + String(IOCTL_VERSION) +
            "\n" +
            NSLocalizedString("itlwm API Version: ", comment: "") + String(drv_info.version)
        verAlert.addButton(withTitle: NSLocalizedString("Quit HeliPort", comment: "")).keyEquivalent = "\r"
        verAlert.addButton(
            withTitle: NSLocalizedString("Visit OpenIntelWireless on GitHub", comment: "")
        )

        NSApplication.shared.activate(ignoringOtherApps: true)

        if verAlert.runModal() == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/OpenIntelWireless")!)
            // Provide a chance to use this App in extreme conditions
            return
        }

        NSApp.terminate(nil)
    }
}
