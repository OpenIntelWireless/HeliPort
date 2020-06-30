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

final class StatusMenu: NSMenu, NSMenuDelegate {

    // - MARK: Properties

    private let heliPortUpdater = SUUpdater()

    private let networkListUpdatePeriod: Double = 5
    private let statusUpdatePeriod: Double = 2

    private var headerLength: Int = 0
    private var networkListUpdateTimer: Timer?
    private var statusUpdateTimer: Timer?

    private var status: itl_80211_state = ITL80211_S_INIT {
        didSet {
            guard isNetworkCardEnabled else {
                StatusBarIcon.off()
                statusItem.title = NSLocalizedString("Wi-Fi: Off", comment: "")
                return
            }

            statusItem.title = NSLocalizedString(status.description, comment: "")

            switch status {
            case ITL80211_S_INIT:
                StatusBarIcon.disconnected()
            case ITL80211_S_AUTH, ITL80211_S_ASSOC:
                StatusBarIcon.connecting()
            case ITL80211_S_RUN:
                StatusBarIcon.connected()
            case ITL80211_S_SCAN:
                // no change in status bar icon when scanning
                break
            default:
                StatusBarIcon.off()
            }
        }
    }

    private var networkItemList = [NSMenuItem]()

    private let maxNetworkListLength = MAX_NETWORK_LIST_LENGTH
    private let networkItemListSeparator: NSMenuItem = {
        let networkItemListSeparator =  NSMenuItem.separator()
        networkItemListSeparator.isHidden = true
        return networkItemListSeparator
    }()

    private var showAllOptions: Bool = false {
        willSet(visible) {
            for idx in 0...6 {
                items[idx].isHidden = !visible
            }
            for idx in 1...2 {
                items[items.count - idx].isHidden = !visible
            }
        }
    }

    private var isNetworkListEmpty: Bool = true {
        willSet(empty) {
            networkItemListSeparator.isHidden = empty
            guard empty else {
                return
            }

            for item in self.networkItemList {
                if let view = item.view as? WifiMenuItemView {
                    view.visible = false
                }
            }
        }
    }

    private var isNetworkCardEnabled: Bool = false {
        willSet(newState) {
            switchItem.title = NSLocalizedString(newState ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", comment: "")
            self.isNetworkListEmpty = !newState
        }
    }

    // - MARK: Menu items

    private let statusItem = NSMenuItem(title: NSLocalizedString("Wi-Fi: Status unavailable", comment: ""))
    private let switchItem = NSMenuItem(
        title: NSLocalizedString("Turn Wi-Fi On", comment: ""),
        action: #selector(clickMenuItem(_:))
    )
    private let bsdItem = NSMenuItem(title: NSLocalizedString("Interface Name: ", comment: "") + "(null)")
    private let macItem = NSMenuItem(title: NSLocalizedString("Address: ", comment: "") + "(null)")
    private let itlwmVerItem = NSMenuItem(title: NSLocalizedString("Version: ", comment: "") + "(null)")

    // - MARK: Init

    init() {
        super.init(title: "")
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

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // - MARK: Setup

    private func setupMenuHeaderAndFooter() {
        addItem(bsdItem)
        addItem(macItem)
        addItem(itlwmVerItem)

        addClickItem(title: NSLocalizedString("Enable Wi-Fi Logging", comment: ""))
        addClickItem(title: NSLocalizedString("Create Diagnostics Report...", comment: ""))
        addClickItem(title: NSLocalizedString("Open Wireless Diagnostics...", comment: ""))

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

        addClickItem(title: NSLocalizedString("Join Other Network...", comment: ""))
        addClickItem(title: NSLocalizedString("Create Network...", comment: ""))
        addClickItem(title: NSLocalizedString("Open Network Preferences...", comment: ""))

        addItem(NSMenuItem.separator())

        addClickItem(title: NSLocalizedString("About HeliPort", comment: ""))
        addClickItem(title: NSLocalizedString("Check for Updates...", comment: ""))
        addClickItem(title: NSLocalizedString("Quit HeliPort", comment: ""), keyEquivalent: "Q")
    }

    // - MARK: Overrides

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

    // - MARK: Actions

    private func addClickItem(title: String, keyEquivalent: String = "") {
        addItem(
            withTitle: title,
            action: #selector(clickMenuItem(_:)),
            keyEquivalent: keyEquivalent
        ).target = self
    }

    private func getDeviceInfo() {
        DispatchQueue.global(qos: .background).async {
            var bsdName = NSLocalizedString("Unavailable", comment: "")
            var macAddr = NSLocalizedString("Unavailable", comment: "")
            var itlwmVer = NSLocalizedString("Unavailable", comment: "")
            var platformInfo = platform_info_t()

            if is_power_on() {
                Log.debug("Wi-Fi powered on")
            } else {
                Log.debug("Wi-Fi powered off")
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

    private func addNetworkItemPlaceholder() -> NSMenuItem {
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

    // - MARK: Action handlers

    @objc private func clickMenuItem(_ sender: NSMenuItem) {
        Log.debug("Clicked \(sender.title)")

        switch sender.title {
        case NSLocalizedString("Turn Wi-Fi On", comment: ""):
            power_on()
        case NSLocalizedString("Turn Wi-Fi Off", comment: ""):
            power_off()
        case NSLocalizedString("Join Other Network...", comment: ""):
            let joinPop = JoinPopWindow()
            joinPop.show()
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
            Log.error("Invalid menu item clicked")
        }
    }

    @objc private func updateStatus() {
        DispatchQueue.global(qos: .background).async {
            var powerState: Bool = false
            let get_power_ret = get_power_state(&powerState)
            var status: UInt32 = 0xFF
            get_80211_state(&status)

            DispatchQueue.main.async {
                if get_power_ret {
                    self.isNetworkCardEnabled = powerState
                }
                self.status = itl_80211_state(rawValue: status)
            }
        }
    }

    @objc private func updateNetworkInfo() {
        guard isNetworkCardEnabled else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            var info = station_info_t()
            get_station_info(&info)
            Log.debug(String(format: "current rate=%03d", info.rate))
        }
    }

    @objc private func updateNetworkList() {
        guard isNetworkCardEnabled else {
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
}
