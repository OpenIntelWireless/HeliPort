//
//  StatusBarIconManager.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/7.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa

class StatusBarIcon: NSObject {
    static var statusBar: NSStatusItem!
    static var timer: Timer?
    static var count: Int = 8
    static func on() {
        timer?.invalidate()
        timer = nil
        disconnected()
    }

    class func off() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = NSImage.init(named: "WiFiStateOff")
    }

    class func connected() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = NSImage.init(named: "WiFiStateOn")
    }

    class func disconnected() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = NSImage.init(named: "WiFiStateDisconnected")
    }

    class func connecting() {
        if timer != nil {
            return
        }
        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.timer = Timer.scheduledTimer(
                timeInterval: 0.3,
                target: self,
                selector: #selector(self.tick),
                userInfo: nil,
                repeats: true
            )
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(
                self.timer!,
                forMode: .common
            )
            currentRunLoop.run()
        }
    }

    @objc class func tick() {
        DispatchQueue.main.async {
            StatusBarIcon.count -= 1
            switch StatusBarIcon.count {
            case 7:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthPoor")
            case 6:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthFair")
            case 5:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthGood")
            case 4:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthExcellent")
            case 3:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthGood")
            case 2:
                statusBar.button?.image = NSImage.init(named: "WiFiSignalStrengthFair")
                StatusBarIcon.count = 8
            default:
                return
            }
        }
    }
}
