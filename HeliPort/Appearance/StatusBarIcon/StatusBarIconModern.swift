//
//  StatusBarIconModern.swift
//  HeliPort
//
//  Created by Bat.bat on 25/6/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class StatusBarIconModern: StatusBarIconProvider {
    var transition: CATransition? {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.2
        return transition
    }
    var off: NSImage { return #imageLiteral(resourceName: "ModernStateOff") }
    var connected: NSImage { return #imageLiteral(resourceName: "ModernStateOn") }
    var disconnected: NSImage { return #imageLiteral(resourceName: "ModernStateDisconnected") }
    var warning: NSImage { return #imageLiteral(resourceName: "ModernStateWarning") }
    var scanning: [NSImage] {
        return [
            #imageLiteral(resourceName: "ModernStateScanning1"),
            #imageLiteral(resourceName: "ModernStateScanning2"),
            #imageLiteral(resourceName: "ModernStateScanning3")
        ]
    }

    func getRssiImage(_ RSSI: Int16) -> NSImage? {
        switch RSSI {
        case ..<(-90): return #imageLiteral(resourceName: "ModernSignalStrengthPoor")
        case ..<(-70): return #imageLiteral(resourceName: "ModernSignalStrengthFair")
        default: return #imageLiteral(resourceName: "ModernSignalStrengthGood")
        }
    }
}
