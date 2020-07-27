//
//  BugReporter.swift
//  HeliPort
//
//  Created by Erik Bautista on 7/26/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class BugReporter {

    public class func generateBugReport() {

        // HeliPort log
        let heliPortPID = ProcessInfo.processInfo.processIdentifier
        let heliPortIdentifier = Bundle.main.bundleIdentifier!
        let heliAppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        let heliBuildVer = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown"
        let heliPortLogCommand = ["show", "--predicate",
                                  "(subsystem == '\(heliPortIdentifier)' && processID == \(heliPortPID))",
            "--debug", "--last", "boot"
        ]
        let heliPortLog = Commands.runCommand(executablePath: .log,
                                              args: heliPortLogCommand) ?? "No logs for HeliPort"

        // itlwm log
        var drv_info = ioctl_driver_info()
        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)
        var itlwmKextVersion = String(cString: &drv_info.driver_version.0)
        var itlwmKextFwVersion = String(cString: &drv_info.fw_version.0)
        if itlwmKextVersion.isEmpty { itlwmKextVersion = "Unknown" }
        if itlwmKextFwVersion.isEmpty { itlwmKextFwVersion = "Unknown" }
        let itlwmLogCommand = ["show", "--predicate",
                               "(process == 'kernel' && eventMessage CONTAINS[c] 'itlwm')",
                               "--last", "5m" // Too many logs can cause this command to be stuck
        ]
        let itlwmLog = Commands.runCommand(executablePath: .log,
                                           args: itlwmLogCommand) ?? "No logs for itlwm"

        let heliPortOutput = "HeliPort Version: \(heliAppVersion) (Build \(heliBuildVer))\n\n" +
        heliPortLog
        let itlwmOutput = "itlwm version: \(itlwmKextVersion) (Firmware: \(itlwmKextFwVersion)\n\n" +
        itlwmLog

        let fileManager = FileManager.default
        guard let desktopPath = fileManager.urls(for: .desktopDirectory,
                                                 in: .userDomainMask).first else {
                                                    Log.error("Could not get desktop path for generated bug report.")
                                                    return
        }

        let reportDir = "HeliPort_report_\(UInt16.random(in: UInt16.min...UInt16.max))"
        let urlReportDir = desktopPath.appendingPathComponent(reportDir, isDirectory: true)

        // Write to files
        do {
            try fileManager.createDirectory(at: urlReportDir, withIntermediateDirectories: true, attributes: nil)
            let heliPortFile = urlReportDir.appendingPathComponent("HeliPort_logs.txt")
            let itlwmFile = urlReportDir.appendingPathComponent("itlwm_logs.txt")
            try heliPortOutput.write(to: heliPortFile, atomically: true, encoding: .utf8)
            try itlwmOutput.write(to: itlwmFile, atomically: true, encoding: .utf8)
        } catch {
            Log.error(error.localizedDescription)
            return
        }

        NSWorkspace.shared.open(urlReportDir)
    }
}
