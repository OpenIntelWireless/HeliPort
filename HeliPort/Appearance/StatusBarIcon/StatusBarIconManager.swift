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

import Cocoa

protocol StatusBarIconProvider {
    var transition: CATransition? { get }
    var off: NSImage { get }
    var connected: NSImage { get }
    var disconnected: NSImage { get }
    var warning: NSImage { get }
    var scanning: [NSImage] { get }
    func getRssiImage(_ RSSI: Int16) -> NSImage?
}

class StatusBarIcon {
    private static var instance: StatusBarIcon?

    private let statusBar: NSStatusItem
    private let icons: StatusBarIconProvider
    private var timer: Timer?
    private var tickIndex: Int = 0
    private var tickDirection: Int = 1

    private init(_ statusBar: NSStatusItem, _ icons: StatusBarIconProvider) {
        self.statusBar = statusBar
        self.icons = icons
    }

    static func shared(statusBar: NSStatusItem? = nil, icons: StatusBarIconProvider? = nil) -> StatusBarIcon {
        if let instance {
            return instance
        }
        guard let statusBar, let icons else {
            fatalError("Must provide statusBar and iconProvider for the first initialization.")
        }
        instance = StatusBarIcon(statusBar, icons)
        return instance!
    }

    func on() {
        stopTimer()
        disconnected()
    }

    func off() {
        stopTimer()
        statusBar.button?.image = icons.off
    }

    func connected() {
        stopTimer()
        statusBar.button?.image = icons.connected
    }

    func disconnected() {
        stopTimer()
        statusBar.button?.image = icons.disconnected
    }

    func connecting() {
        guard timer == nil else { return }
        tickIndex = 0
        tickDirection = 1
        DispatchQueue.global(qos: .default).async {
            self.timer = Timer.scheduledTimer(
                timeInterval: 0.3,
                target: self,
                selector: #selector(self.tick),
                userInfo: nil,
                repeats: true
            )
            self.timer?.fire()
            RunLoop.current.add(self.timer!, forMode: .common)
            RunLoop.current.run()
        }
    }

    func warning() {
        stopTimer()
        statusBar.button?.image = icons.warning
    }

    func error() {
        stopTimer()
        statusBar.button?.image = #imageLiteral(resourceName: "WiFiStateError")
    }

    func signalStrength(rssi: Int16) {
        stopTimer()
        statusBar.button?.image = icons.getRssiImage(rssi)
    }

    func getRssiImage(rssi: Int16) -> NSImage? {
        return icons.getRssiImage(rssi)
    }

    @objc private func tick() {
        DispatchQueue.main.async {
            if let transition = self.icons.transition {
                self.statusBar.button?.layer?.add(transition, forKey: kCATransition)
            }
            self.statusBar.button?.image = self.icons.scanning[self.tickIndex]

            self.tickIndex += self.tickDirection
            if self.tickIndex == 0 || self.tickIndex == self.icons.scanning.endIndex - 1 {
                self.tickDirection *= -1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
