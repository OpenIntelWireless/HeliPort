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

import Foundation

class BugReporter {

    public class func generateBugReport() {
        DispatchQueue.global(qos: .background).async {
            let heliPortLogCommand = ["show", "--predicate",
                                      "(subsystem == '\(Bundle.main.bundleIdentifier!)')",
                                      "--debug", "--last", "5m"
            ]
            let heliportOutput = Commands.runCommand(executablePath: .log,
                                                     args: heliPortLogCommand) ?? "No logs for HeliPort"
            print(heliportOutput)
            let itlwmLogCommand = ["show", "--predicate",
                                   "(process == 'kernel' && eventMessage CONTAINS[c] 'itlwm')",
                                   "--last", "5m"
            ]
            let itlwmOutput = Commands.runCommand(executablePath: .log,
                                                  args: itlwmLogCommand) ?? "No logs for itlwm"

            
        }
    }

}
