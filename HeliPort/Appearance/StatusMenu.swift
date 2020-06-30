//
//  StatusMenuView.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/5.
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
import Sparkle

class StatusMenu: NSMenu, NSMenuDelegate {
    let heliPortUpdater = SUUpdater()

    let networkListUpdatePeriod: Double = 5
    let statusUpdatePeriod: Double = 2

    var headerLength: Int = 0
    var networkListUpdateTimer: Timer?
    var statusUpdateTimer: Timer?

    let statusItem = NSMenuItem(
        title: NSLocalizedString("Wi-Fi: Status unavailable", comment: ""),
        action: nil,
        keyEquivalent: ""
    )
    var status: UInt32 = 0 {
        didSet {
            var statusText = ""
            switch status {
            case ITL80211_S_INIT.rawValue:
                statusText = "Wi-Fi: On"
                StatusBarIcon.disconnected()
            case ITL80211_S_SCAN.rawValue:
                statusText = "Wi-Fi: Looking for Networks..."
            case ITL80211_S_AUTH.rawValue, ITL80211_S_ASSOC.rawValue:
                statusText = "Wi-Fi: Connecting"
                StatusBarIcon.connecting()
            case ITL80211_S_RUN.rawValue:
                statusText = "Wi-Fi: Connected"
                StatusBarIcon.connected()
            default:
                statusText = "Wi-Fi: Status unavailable"
            }
            if !isNetworkEnabled {
                statusText = "Wi-Fi: Off"
                StatusBarIcon.off()
            }
            statusItem.title = NSLocalizedString(statusText, comment: "")
        }
    }

    let switchItem = NSMenuItem(
        title: NSLocalizedString("Turn Wi-Fi Off", comment: ""),
        action: #selector(clickMenuItem(_:)),
        keyEquivalent: ""
    )
    let bsdItem = NSMenuItem(
        title: NSLocalizedString("Interface Name: ", comment: "") + "(null)",
        action: nil,
        keyEquivalent: ""
    )
    let macItem = NSMenuItem(
        title: NSLocalizedString("Address: ", comment: "") + "(null)",
        action: nil,
        keyEquivalent: ""
    )
    let itlwmVerItem = NSMenuItem(
        title: NSLocalizedString("Version: ", comment: "") + "(null)",
        action: nil,
        keyEquivalent: ""
    )
    var networkItemList = [NSMenuItem]()
    let maxNetworkListLength = MAX_NETWORK_LIST_LENGTH
    let networkItemListSeparator: NSMenuItem = {
        let networkItemListSeparator =  NSMenuItem.separator()
        networkItemListSeparator.isHidden = true
        return networkItemListSeparator
    }()

    var showAllOptions: Bool = false {
        willSet(visible) {
            for idx in 0...6 {
                items[idx].isHidden = !visible
            }
            for idx in 1...2 {
                items[items.count - idx].isHidden = !visible
            }
        }
    }

    var isNetworkListEmpty: Bool = true {
        willSet(empty) {
            networkItemListSeparator.isHidden = empty
            if empty {
                for item in self.networkItemList {
                    if let view = item.view as? WifiMenuItemView {
                        view.visible = false
                    }
                }
            }
        }
    }

    var isNetworkEnabled: Bool = true {
        willSet(newState) {
            switchItem.title = NSLocalizedString(newState ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", comment: "")
            self.isNetworkListEmpty = !newState
        }
    }

    override init(title: String) {
        super.init(title: title)
        minimumWidth = CGFloat(285.0)
        delegate = self
        setupMenuHeaderAndFooter()
        updateNetworkList()
        getDeviceInfo()

        DispatchQueue.global(qos: .default).async {
            self.statusUpdateTimer = Timer.scheduledTimer(
                timeInterval: self.statusUpdatePeriod,
                target: self,
                selector: #selector(self.updateStatus),
                userInfo: nil,
                repeats: true
            )
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(self.statusUpdateTimer!, forMode: .common)
            currentRunLoop.run()
        }
    }

    func setupMenuHeaderAndFooter() {
        addItem(bsdItem)
        addItem(macItem)
        addItem(itlwmVerItem)
        addItem(
            withTitle: NSLocalizedString("Enable Wi-Fi Logging", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Create Diagnostics Report...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Open Wireless Diagnostics...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(NSMenuItem.separator())

        addItem(statusItem)
        addItem(switchItem)
        switchItem.target = self
        addItem(NSMenuItem.separator())

        headerLength = items.count

        for _ in 1...maxNetworkListLength {
            networkItemList.append(addNetworkItemPlaceholder())
        }

        addItem(networkItemListSeparator)

        addItem(
            withTitle: NSLocalizedString("Join Other Network...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Create Network...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Open Network Preferences...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(NSMenuItem.separator())

        addItem(
            withTitle: NSLocalizedString("About HeliPort", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Check for Updates...", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        ).target = self

        addItem(
            withTitle: NSLocalizedString("Quit HeliPort", comment: ""),
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: "Q"
        ).target = self
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        for item in networkItemList {
            if let view = item.view as? WifiMenuItemView {
                view.checkHighlight()
            }
        }
    }

    func menuWillOpen(_ menu: NSMenu) {

        showAllOptions = (NSApp.currentEvent?.modifierFlags.contains(.option))!

        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.networkListUpdateTimer = Timer.scheduledTimer(
                timeInterval: self.networkListUpdatePeriod,
                target: self,
                selector: #selector(self.updateNetworkList),
                userInfo: nil,
                repeats: true
            )
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(self.networkListUpdateTimer!, forMode: .common)
            currentRunLoop.run()
        }
        updateNetworkInfo()
        updateNetworkList()
    }

    func menuDidClose(_ menu: NSMenu) {
        networkListUpdateTimer?.invalidate()
    }

    @objc func clickMenuItem(_ sender: NSMenuItem) {
        print(sender.title)
        switch sender.title {
        case NSLocalizedString("Turn Wi-Fi On", comment: ""):
            power_on()
        case NSLocalizedString("Turn Wi-Fi Off", comment: ""):
            power_off()
        case NSLocalizedString("Join Other Network...", comment: ""):
            let joinPop = JoinPopWindow.init(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: 450,
                    height: 247
                ),
                styleMask: .titled,
                backing: .buffered,
                defer: false
            )
            joinPop.makeKeyAndOrderFront(self)
        case NSLocalizedString("Create Network...", comment: ""):
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("FUNCTION NOT IMPLEMENTED", comment: "")
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        case NSLocalizedString("Open Network Preferences...", comment: ""):
            NSWorkspace.shared.openFile("/System/Library/PreferencePanes/Network.prefPane")
        case NSLocalizedString("Check for Updates...", comment: ""):
            heliPortUpdater.checkForUpdates(self)
        case NSLocalizedString("About HeliPort", comment: ""):
            NSApplication.shared.orderFrontStandardAboutPanel()
            NSApplication.shared.activate(ignoringOtherApps: true)
        case NSLocalizedString("Quit HeliPort", comment: ""):
            exit(0)
        default:
            print("Default")
        }
    }

    func getDeviceInfo() {
        DispatchQueue.global(qos: .background).async {
            var bsdName = NSLocalizedString("Unavailable", comment: "")
            var macAddr = NSLocalizedString("Unavailable", comment: "")
            var itlwmVer = NSLocalizedString("Unavailable", comment: "")
            var platformInfo = platform_info_t()
            if is_power_on() {
                print("Wi-Fi open")
            } else {
                print("Wi-Fi close")
            }
            if get_platform_info(&platformInfo) {
                bsdName = String(cString: &platformInfo.device_info_str.0)
                macAddr = NetworkManager.getMACAddressFromBSD(bsd: bsdName) ?? macAddr
                itlwmVer = String(cString: &platformInfo.driver_info_str.0)
            }
            DispatchQueue.main.async {
                self.bsdItem.title = NSLocalizedString("Interface Name: ", comment: "") + bsdName
                self.macItem.title = NSLocalizedString("Address: ", comment: "") + macAddr
                self.itlwmVerItem.title = NSLocalizedString("Version: ", comment: "") + itlwmVer
            }
        }
    }

    @objc func updateStatus() {
        DispatchQueue.global(qos: .background).async {
            var powerState: Bool = false
            let get_power_ret = get_power_state(&powerState)
            var status: UInt32 = 0xFF
            get_80211_state(&status)
            DispatchQueue.main.async {
                if get_power_ret {
                    self.isNetworkEnabled = powerState
                }
                self.status = status
            }
        }
    }

    func addNetworkItemPlaceholder() -> NSMenuItem {
        let item = addItem(
            withTitle: "placeholder",
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: ""
        )
        item.view = WifiMenuItemView(
            networkInfo: NetworkInfo(
                ssid: "placeholder",
                connected: false,
                rssi: 0
            )
        )
        guard let view = item.view as? WifiMenuItemView else {
            return item
        }
        view.visible = false
        view.translatesAutoresizingMaskIntoConstraints = false
        guard let supView = view.superview else {
            return item
        }
        view.widthAnchor.constraint(equalTo: supView.widthAnchor).isActive = true
        view.heightAnchor.constraint(equalTo: supView.heightAnchor).isActive = true
        return item
    }
    
    @objc func updateNetworkInfo() {
        if !isNetworkEnabled {
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            var info = station_info_t()
            get_station_info(&info)
            print(String(format: "current rate=%03d", info.rate))
        }
    }

    @objc func updateNetworkList() {
        if !isNetworkEnabled {
            return
        }

        NetworkManager.scanNetwork { networkList in
            self.isNetworkListEmpty = networkList.count == 0
            var networkList = networkList
            for index in 0 ..< self.networkItemList.count {
                if networkList.count > 0, let view = self.networkItemList[index].view as? WifiMenuItemView {
                    view.networkInfo = networkList.removeFirst()
                    view.visible = true
                }
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
