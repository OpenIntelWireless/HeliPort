//
//  StatusBarIconLegacy.swift
//  HeliPort
//
//  Created by Bat.bat on 25/6/2024.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class StatusBarIconLegacy: StatusBarIconProvider {
    var transition: CATransition? { return nil }
    var off: NSImage { return #imageLiteral(resourceName: "LegacyStateOff") }
    var connected: NSImage { return #imageLiteral(resourceName: "LegacyStateOn") }
    var disconnected: NSImage { return #imageLiteral(resourceName: "LegacyStateDisconnected") }
    var warning: NSImage { return #imageLiteral(resourceName: "LegacyStateWarning") }
    var scanning: [NSImage] {
        return [
            #imageLiteral(resourceName: "LegacyStateScanning1"),
            #imageLiteral(resourceName: "LegacyStateScanning2"),
            #imageLiteral(resourceName: "LegacyStateScanning3"),
            #imageLiteral(resourceName: "LegacyStateScanning4")
        ]
    }

    func getRssiImage(_ RSSI: Int16) -> NSImage? {
        switch RSSI {
        case ..<(-100): return #imageLiteral(resourceName: "LegacySignalStrengthPoor")
        case ..<(-80): return #imageLiteral(resourceName: "LegacySignalStrengthFair")
        case ..<(-60): return #imageLiteral(resourceName: "LegacySignalStrengthGood")
        default: return #imageLiteral(resourceName: "LegacySignalStrengthExcellent")
        }
    }
}
