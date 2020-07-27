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

        // MARK: HeliPort log

        let appIdentifier = Bundle.main.bundleIdentifier!
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        let appBuildVer = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown"
        let appLogCommand = ["show", "--predicate",
                                  "(subsystem == '\(appIdentifier)')",
                                  "--debug", "--last", "boot"]
        let appLog = Commands.runCommand(executablePath: .log,
                                              args: appLogCommand) ?? "No logs for HeliPort"

        // MARK: itlwm log

        var drv_info = ioctl_driver_info()
        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)
        var itlwmVersion = String(cString: &drv_info.driver_version.0)
        var itlwmFwVersion = String(cString: &drv_info.fw_version.0)
        if itlwmVersion.isEmpty { itlwmVersion = "Unknown" }
        if itlwmFwVersion.isEmpty { itlwmFwVersion = "Unknown" }
        let itlwmLogCommand = ["show", "--predicate",
                               "(process == 'kernel' " +
                               "&& eventMessage CONTAINS[c] 'itlwm')",
                               "--last", "boot"]
        let itlwmLog = Commands.runCommand(executablePath: .log,
                                           args: itlwmLogCommand) ?? "No logs for itlwm"

        // MARK: Get itlwm name if loaded (itlwm or itlwmx)

        let kextstatCommand = ["-c", "kextstat"]
        let itlwmLoaded = Commands.runCommand(executablePath: .shell, args: kextstatCommand)
        var itlwmName: String?
        if let regex = try? NSRegularExpression.init(pattern: "\\b(itlwm\\w*)\\b", options: []), itlwmLoaded != nil {
            let firstMatch = regex.firstMatch(in: itlwmLoaded!,
                                            options: [],
                                            range: NSRange(location: 0, length: itlwmLoaded!.count))
            if let range = firstMatch?.range(at: 1) {
                if let swiftRange = Range(range, in: itlwmLoaded!) {
                    itlwmName = String(itlwmLoaded![swiftRange])
                }
            }
        }

        // MARK: Output String

        let appOutput = """
                             \(appLog)

                             HeliPort Version: \(appVersion) (Build \(appBuildVer))
                             """
        let itlwmOutput = """
                          \(itlwmLog)

                          \(itlwmName != nil ? """
                                                 \(itlwmName!) loaded
                                                 \(itlwmName!) version: \(itlwmVersion) (Firmware: \(itlwmFwVersion))
                                                 """ : "Kext not loaded")
                          """

        let fileManager = FileManager.default
        guard let desktopPath = fileManager.urls(for: .desktopDirectory,
                                                 in: .userDomainMask).first else {
                                                    Log.error("Could not get desktop path for generated bug report.")
                                                    return
        }

        let reportDir = "bugreport_\(UInt16.random(in: UInt16.min...UInt16.max))"
        let urlReportDir = desktopPath.appendingPathComponent(reportDir, isDirectory: true)

        // MARK: Write to file

        do {
            try fileManager.createDirectory(at: urlReportDir, withIntermediateDirectories: true, attributes: nil)
            let heliPortFile = urlReportDir.appendingPathComponent("HeliPort_logs.log")
            let itlwmFile = urlReportDir.appendingPathComponent("\(itlwmName ?? "itlwm")_logs.log")
            try appOutput.write(to: heliPortFile, atomically: true, encoding: .utf8)
            try itlwmOutput.write(to: itlwmFile, atomically: true, encoding: .utf8)
        } catch {
            Log.error(error.localizedDescription)
            return
        }

        NSWorkspace.shared.open(urlReportDir)
    }
}
