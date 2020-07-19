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

        checkRunPath()
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
            #if !DEBUG
            let itlAlert = NSAlert()
            _ = showCriticalAlert(
                itlAlert,
                msg: "itlwm is not running",
                unlocalizedInfo: nil,
                optTitles: ["Dismiss"]
            )
            #endif
            return false
        }

        Log.debug("Loaded itlwm \(version) as \(interface)")

        return true
    }

    // Due to macOS App Translocation, users must store this app in /Applications
    // Otherwise Sparkle and "Launch At Login" will not function correctly
    // Ref: https://lapcatsoftware.com/articles/app-translocation.html
    private func checkRunPath() {
        let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents

        #if DEBUG
        // Normal users should never use the Debug Version
        guard pathComponents[pathComponents.count - 2] != "Debug" else {
            return
        }
        #else
        guard pathComponents[pathComponents.count - 2] != "Applications"
                //|| pathComponents[pathComponents.count - 2] != "Release"
        else {
            return
        }
        #endif

        Log.error("Running path unexpected!")

        let pathAlert = NSAlert()
        _ = showCriticalAlert(
            pathAlert,
            msg: "HeliPort running at an unexpected path",
            unlocalizedInfo: nil,
            optTitles: ["Quit HeliPort"]
        )
        NSApp.terminate(nil)
    }

    private func checkAPI() {

        // It's fine for users to bypass this check by launching HeliPort first then loading itlwm in terminal
        // Only advanced users do so, and they know what they are doing
        guard checkDriver(), IOCTL_VERSION != drv_info.version else {
            return
        }

        Log.error("itlwm API mismatch!")

        #if !DEBUG
        let apiAlert = NSAlert()
        let alertReturn = showCriticalAlert(
            apiAlert,
            msg: "itlwm Version Mismatch",
            unlocalizedInfo: NSLocalizedString("HeliPort API Version: ", comment: "") + String(IOCTL_VERSION) +
                             "\n" +
                             NSLocalizedString("itlwm API Version: ", comment: "") + String(drv_info.version),
            optTitles: ["Quit HeliPort", "Visit OpenIntelWireless on GitHub"]
        )

        if alertReturn == .alertSecondButtonReturn {
            NSWorkspace.shared.open(URL(string: "https://github.com/OpenIntelWireless")!)
            return
        }

        NSApp.terminate(nil)
        #endif
    }

    private func showCriticalAlert(
        _ alert: NSAlert,
        msg: String,
        unlocalizedInfo: String?,
        optTitles: [String?]
    ) -> NSApplication.ModalResponse {

        alert.alertStyle = .critical
        alert.messageText = NSLocalizedString(msg, comment: "")
        alert.informativeText = unlocalizedInfo ?? ""

        optTitles.forEach {
            if $0 != nil {
                alert.addButton(withTitle: NSLocalizedString($0!, comment: ""))
            }
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal()
    }
}
