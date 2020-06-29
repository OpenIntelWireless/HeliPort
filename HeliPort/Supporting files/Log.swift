//
//  Log.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation
import os.log

final class Log {
    static func debug(_ message: String) {
        os_log("%@", log: .default, type: .debug, message)
    }
}
