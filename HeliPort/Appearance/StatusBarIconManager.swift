//
//  StatusBarIconManager.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/7.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
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
    static var count: Int = 6
    static func on() {
        timer?.invalidate()
        timer = nil
        disconnected()
    }

    class func off() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateOff")
    }

    class func connected() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateOn")
    }

    class func disconnected() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateDisconnected")
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

    class func warning() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateWarning")
    }

    class func error() {
        timer?.invalidate()
        timer = nil
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateError")
    }

    class func signalStrength(rssi: Int16) {
        timer?.invalidate()
        timer = nil
        let signalImage = getRssiImage(rssi)
        statusBar.button?.image = signalImage
    }

    @objc class func tick() {
        DispatchQueue.main.async {
            StatusBarIcon.count -= 1
            var newImage: NSImage?
            
            switch StatusBarIcon.count {
            case 5:
                newImage = #imageLiteral(resourceName: "WiFiStateScanning1")
            case 4:
                newImage = #imageLiteral(resourceName: "WiFiStateScanning2")
            case 3:
                newImage = #imageLiteral(resourceName: "WiFiStateScanning3")
            case 2:
                newImage = #imageLiteral(resourceName: "WiFiStateScanning2")
                StatusBarIcon.count = 6
            default:
                return
            }

            if let statusBarButton = statusBar.button {
                let fadeTransition = CATransition()
                fadeTransition.type = .fade
                fadeTransition.duration = 0.3
                statusBarButton.layer?.add(fadeTransition, forKey: kCATransition)
                statusBarButton.image = newImage
            }
        }
    }

    class func getRssiImage(_ RSSI: Int16) -> NSImage? {
        var signalImageName: NSImage
        switch RSSI {
        case ..<(-100):
            signalImageName = #imageLiteral(resourceName: "WiFiStateScanning1")
        case ..<(-70):
            signalImageName = #imageLiteral(resourceName: "WiFiSignalStrengthGood")
        default:
            signalImageName = #imageLiteral(resourceName: "WiFiStateOn")
        }
        return signalImageName
    }
}
