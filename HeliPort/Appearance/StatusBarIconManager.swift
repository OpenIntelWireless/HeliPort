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
    static var timer: Timer?
    static var count:Int = 8
    static func on() {
        timer?.invalidate()
        connecting()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
           disconnected()
        }
    }

    class func off() {
        timer?.invalidate()
        statusBar.button?.image = NSImage.init(named: "AirPortOff")
    }

    class func connected() {
        timer?.invalidate()
        statusBar.button?.image = NSImage.init(named: "AirPort4")
    }

    class func disconnected() {
        timer?.invalidate()
        statusBar.button?.image = NSImage.init(named: "AirPortInMenu0")
    }

    class func connecting() {
        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.tick), userInfo: nil, repeats: true)
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(self.timer!, forMode: .common)
            currentRunLoop.run()
        }
    }
    
    @objc class func tick() {
        DispatchQueue.main.async {
            StatusBarIcon.count -= 1
            switch StatusBarIcon.count {
            case 7:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning1")
                break
            case 6:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning2")
                break
            case 5:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning3")
                break
            case 4:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning4")
                break
            case 3:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning3")
                break
            case 2:
                statusBar.button?.image = NSImage.init(named: "AirPortScanning2")
                StatusBarIcon.count = 8
                break
            default:
                return
            }
        }
    }
}
