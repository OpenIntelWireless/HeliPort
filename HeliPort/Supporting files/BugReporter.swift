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
                                  "(subsystem == '\(appIdentifier)')", "--info", "--last", "boot"]
        let appLog = Commands.execute(executablePath: .log, args: appLogCommand).0 ?? "No logs for HeliPort"

        // MARK: itlwm log

        var drv_info = ioctl_driver_info()
        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)
        var itlwmVersion = String(cString: &drv_info.driver_version.0)
        var itlwmFwVersion = String(cString: &drv_info.fw_version.0)
        if itlwmVersion.isEmpty { itlwmVersion = "Unknown" }
        if itlwmFwVersion.isEmpty { itlwmFwVersion = "Unknown" }
        let itlwmLogCommand = ["show", "--predicate",
                               "(process == 'kernel' && eventMessage CONTAINS[c] 'itlwm')",
                               "--last", "boot"]
        let itlwmLog = Commands.execute(executablePath: .log, args: itlwmLogCommand).0 ?? "No logs for itlwm"

        // MARK: Get itlwm name if loaded (itlwm or itlwmx)

        let kextstatCommand = ["-c", "kextstat"]
        let itlwmLoaded = Commands.execute(executablePath: .shell, args: kextstatCommand)
        var itlwmName: String?
        if let regex = try? NSRegularExpression.init(pattern: "\\b(itlwm\\w*)\\b", options: []), itlwmLoaded.0 != nil {
            let firstMatch = regex.firstMatch(in: itlwmLoaded.0!,
                                            options: [],
                                            range: NSRange(location: 0, length: itlwmLoaded.0!.count))
            if let range = firstMatch?.range(at: 1) {
                if let swiftRange = Range(range, in: itlwmLoaded.0!) {
                    itlwmName = String(itlwmLoaded.0![swiftRange])
                }
            }
        }

        // MARK: Output String

        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
        let dateRan = "Time ran: \(formatter.string(from: date))"
        let appOutput = """
                        \(appLog)

                        \(dateRan)
                        HeliPort Version: \(appVersion) (Build \(appBuildVer))
                        """
        let itlwmOutput = """
                          \(itlwmLog)

                          \(dateRan)
                          \(itlwmName != nil ? """
                                                 \(itlwmName!) loaded
                                                 \(itlwmName!) version: \(itlwmVersion) (Firmware: \(itlwmFwVersion))
                                                 """ : "Kext not loaded")
                          """

        let fileManager = FileManager.default
        guard let desktopUrl = fileManager.urls(for: .desktopDirectory,
                                                 in: .userDomainMask).first else {
                                                    Log.error("Could not get desktop path to generate bug report.")
                                                    return
        }

        let reportDirName = "bugreport_\(UInt16.random(in: UInt16.min...UInt16.max))"
        let reportDirUrl = desktopUrl.appendingPathComponent(reportDirName, isDirectory: true)

        // MARK: Write to files

        do {
            try fileManager.createDirectory(at: reportDirUrl, withIntermediateDirectories: true, attributes: nil)
            let heliPortFile = reportDirUrl.appendingPathComponent("HeliPort_logs.log")
            let itlwmFile = reportDirUrl.appendingPathComponent("\(itlwmName ?? "itlwm")_logs.log")
            try appOutput.write(to: heliPortFile, atomically: true, encoding: .utf8)
            try itlwmOutput.write(to: itlwmFile, atomically: true, encoding: .utf8)
        } catch {
            Log.error("\(error)")
            return
        }

        // MARK: Zip file

        let zipName = reportDirName + ".zip"
        let zipCommand = ["-c", "cd \(desktopUrl.path) && " +
                                "zip -r -X -m \(zipName) \(reportDirName)"]
        let outputExitCode = Commands.execute(executablePath: .shell, args: zipCommand).1
        guard outputExitCode == 0 else {
            Log.error("Could not create zip file")
            return
        }

        // MARK: Select zip file

        NSWorkspace.shared.selectFile("\(desktopUrl.path)/\(zipName)",
                                      inFileViewerRootedAtPath: desktopUrl.path)
    }
}
