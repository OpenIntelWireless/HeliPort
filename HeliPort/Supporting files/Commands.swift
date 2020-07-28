//
//  CommandLine.swift
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

import Foundation

class Commands {
    enum ExecutablePath: String {
        case shell = "/bin/sh"
        case log = "/usr/bin/log"
    }

    // MARK: Run command and returns the output and exit status.

    public class func execute(executablePath: ExecutablePath, args: [String]) -> (String?, Int32) {
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        if #available(OSX 10.13, *) {
            process.executableURL = URL(fileURLWithPath: executablePath.rawValue)
        } else {
            process.launchPath = executablePath.rawValue
        }
        process.arguments = args
        if #available(OSX 10.13, *) {
            guard (try? process.run()) != nil else {
                Log.debug("Could not run command")
                return (nil, 1)
            }
        } else {
            process.launch()
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8),
            !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, process.terminationStatus)
        }

        return (output.trimmingCharacters(in: .whitespacesAndNewlines), process.terminationStatus)
    }

}
