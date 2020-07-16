//
//  main.swift
//  HeliPort Launcher
//
//  Created by Bat.bat on 7/14/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {

        // Credit sindresorhus https://github.com/sindresorhus/LaunchAtLogin
        let bundleId = Bundle.main.bundleIdentifier!
        let mainBundleId = bundleId.replacingOccurrences(of: "-Launcher", with: "")

        // Ensure the app is not already running
        guard NSRunningApplication.runningApplications(withBundleIdentifier: mainBundleId).isEmpty else {
            NSApp.terminate(nil)
            return
        }

        let pathComponents = (Bundle.main.bundlePath as NSString).pathComponents
        let mainPath = NSString.path(withComponents: Array(pathComponents[0...(pathComponents.count - 5)]))
        NSWorkspace.shared.launchApplication(mainPath)
        NSApp.terminate(nil)
    }
}

private let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
