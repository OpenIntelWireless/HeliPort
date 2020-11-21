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
import OSLog

class BugReporter {

    private class func generateHeliPortLog() -> String {

        // MARK: HeliPort log

        let appIdentifier = Bundle.main.bundleIdentifier!

        if #available(OSX 10.15, *) {
            do {
                let logStore = try OSLogStore.local()
                let lastBoot = logStore.position(timeIntervalSinceLatestBoot: 0)
                let matchingPredicate = NSPredicate(format: "subsystem == '\(appIdentifier)'")
                let enumerator = try logStore.getEntries(with: [],
                                                         at: lastBoot,
                                                         matching: matchingPredicate)
                let allEntries = Array(enumerator)
                let osLogEntryLogObjects = allEntries.compactMap { $0 as? OSLogEntryLog }
                var entryStr = ""
                for item in osLogEntryLogObjects where item.subsystem == appIdentifier {
                    entryStr += "\n\(item.date);    \(item.subsystem);    \(item.category);    \(item.composedMessage)"
                }
                if entryStr.count == 0 {
                    entryStr += "No logs for HeliPort."
                }
                return entryStr
            } catch {
                Log.error("Could not generate bug report \(error)")
                return "No logs for HeliPort."
            }
        } else {
            let appLogCommand = ["show", "--predicate",
                                      "(subsystem == '\(appIdentifier)')", "--info", "--last", "boot"]
            let appLog = Commands.execute(executablePath: .log, args: appLogCommand).0 ?? "No logs for HeliPort"
            return appLog
        }
    }

    private class func generateItlwmLog() -> String {
        if #available(OSX 11.0, *) {
            return "Cannot get itlwm logs for devices on macOS Big Sur or higher.\n" +
                    "Please follow this guide to get itlwm logs: \n" +
                    "https://openintelwireless.github.io/itlwm/Troubleshooting.html#using-dmesg"
        } else {
            let itlwmLogCommand = ["show", "--predicate",
                                   "(process == 'kernel' && eventMessage CONTAINS[c] 'itlwm')",
                                   "--last", "boot"]
            let itlwmLog = Commands.execute(executablePath: .log, args: itlwmLogCommand).0 ?? "No logs for itlwm"
            return itlwmLog
        }
    }

    public class func generateBugReport() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "Unknown"
        let appBuildVer = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "Unknown"

        let appLog = generateHeliPortLog()

        // MARK: itlwm log

        var drv_info = ioctl_driver_info()
        _ = ioctl_get(Int32(IOCTL_80211_DRIVER_INFO.rawValue), &drv_info, MemoryLayout<ioctl_driver_info>.size)
        var itlwmVer = String(cString: &drv_info.driver_version.0)
        var itlwmFwVer = String(cString: &drv_info.fw_version.0)
        if itlwmVer.isEmpty { itlwmVer = "Unknown" }
        if itlwmFwVer.isEmpty { itlwmFwVer = "Unknown" }

        let itlwmLog = generateItlwmLog()

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
        let osVersion = ProcessInfo().operatingSystemVersionString
        let appOutput = """
                        \(appLog)

                        \(dateRan)
                        HeliPort Version: \(appVersion) (Build \(appBuildVer))

                        macOS \(osVersion)
                        """
        let itlwmOutput = """
                          \(itlwmLog)

                          \(dateRan)
                          \(itlwmName != nil ?  "\(itlwmName!) loaded version: \(itlwmVer) (Firmware: \(itlwmFwVer))" :
                                "Kext not loaded")

                          macOS \(osVersion)
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
