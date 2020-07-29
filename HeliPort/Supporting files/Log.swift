//
//  Log.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import os.log

final class Log {
    static func debug(_ message: String) {
        os_log("%@", log: .heliPort, type: .debug, message)
    }

    static func error(_ message: String) {
        os_log("%@", log: .heliPort, type: .error, message)
    }
}

extension OSLog {
    static let heliPort = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "HeliPort")
}
