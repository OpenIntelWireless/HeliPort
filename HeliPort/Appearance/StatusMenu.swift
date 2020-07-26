//
//  StatusMenuView.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/5.
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
            /* Only allow if network card is enabled or if the network card does not load
             either due to itlwm not loaded or just not able to receive info
             This prevents cards that are working but are "off" to not change the
             Status from "WiFi off" to another status. i.e "WiFi: on". */
            guard isNetworkCardEnabled || !isNetworkCardAvailable else {
                return
            }

            statusItem.title = NSLocalizedString(status.description)

            switch status {
            case ITL80211_S_INIT:
                StatusBarIcon.disconnected()
            case ITL80211_S_AUTH, ITL80211_S_ASSOC:
                StatusBarIcon.connecting()
            case ITL80211_S_RUN:
                DispatchQueue.global(qos: .background).async {
                    let isReachable = NetworkManager.isReachable()
                    var staInfo = station_info_t()
                    get_station_info(&staInfo)
                    DispatchQueue.main.async {
                        guard isReachable else {
                            StatusBarIcon.warning()
                            return
                        }
                        StatusBarIcon.signalStrength(RSSI: staInfo.rssi)
                    }
                }
            case ITL80211_S_SCAN:
                // no change in status bar icon when scanning
                break
            default:
                StatusBarIcon.error()
            }
        }
    }

    private var showAllOptions: Bool = false {
        willSet(visible) {
            let hiddenItems: [NSMenuItem] = [
                bsdItem,
                macItem,
                itlwmVerItem,
                enableLoggingItem,
                createReportItem,
                diagnoseItem,
                hardwareInfoSeparator,

                toggleLaunchItem,
                checkUpdateItem,
                quitSeparator,
                quitItem
            ]

            let connectedNetworkInfoItems: [NSMenuItem] = [
                disconnectItem,
                ipAddresssItem,
                routerItem,
                internetItem,
                securityItem,
                bssidItem,
                channelItem,
                countryCodeItem,
                rssiItem,
                noiseItem,
                txRateItem,
                phyModeItem,
                mcsIndexItem,
                nssItem
            ]

            let enabledNetworkCardItems: [NSMenuItem] = [
                createNetworkItem,
                manuallyJoinItem
            ]

            let notImplementedItems: [NSMenuItem] = [
                enableLoggingItem,
                createReportItem,
                diagnoseItem,

                securityItem,
                countryCodeItem,
                nssItem,

                createNetworkItem
            ]

            for item in hiddenItems { item.isHidden = !visible }
            for item in enabledNetworkCardItems { item.isHidden = !isNetworkCardAvailable }
            for item in connectedNetworkInfoItems { item.isHidden = !(visible && status == ITL80211_S_RUN) }
            for item in notImplementedItems { item.isHidden = true }
        }
    }

    private var isNetworkConnected: Bool = false

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

    private var isNetworkCardAvailable: Bool = true {
        willSet(newState) {
            if !newState {
                self.isNetworkCardEnabled = false
            }
        }
    }

    private var isNetworkCardEnabled: Bool = false {
        willSet(newState) {
            statusItem.title = NSLocalizedString(newState ? "Wi-Fi: On" : "Wi-Fi: Off")
            switchItem.title = NSLocalizedString(newState ? "Turn Wi-Fi Off" : "Turn Wi-Fi On")
            if newState != isNetworkCardEnabled {
                newState ? StatusBarIcon.on() : StatusBarIcon.off()
                self.isNetworkListEmpty = true
            }
        }
    }

    private var isAutoLaunch: Bool = false {
        willSet(newState) {
            toggleLaunchItem.state = newState ? .on : .off
        }
    }

    // - MARK: Menu items

    private let statusItem = NSMenuItem(title: NSLocalizedString("Wi-Fi: Status unavailable"))
    private let switchItem = NSMenuItem(
        title: NSLocalizedString("Turn Wi-Fi On"),
        action: #selector(clickMenuItem(_:))
    )
    private let bsdItem = NSMenuItem(title: NSLocalizedString("Interface Name: ") + "(null)")
    private let macItem = NSMenuItem(title: NSLocalizedString("Address: ") + "(null)")
    private let itlwmVerItem = NSMenuItem(title: NSLocalizedString("Version: ") + "(null)")

    private let enableLoggingItem = NSMenuItem(title: NSLocalizedString("Enable Wi-Fi Logging"))
    private let createReportItem = NSMenuItem(title: NSLocalizedString("Create Diagnostics Report..."))
    private let diagnoseItem = NSMenuItem(title: NSLocalizedString("Open Wireless Diagnostics..."))
    private let hardwareInfoSeparator = NSMenuItem.separator()

    private var networkItemList = [NSMenuItem]()
    private let maxNetworkListLength = MAX_NETWORK_LIST_LENGTH
    private let networkItemListSeparator: NSMenuItem = {
        let networkItemListSeparator =  NSMenuItem.separator()
        networkItemListSeparator.isHidden = true
        return networkItemListSeparator
    }()

    private let manuallyJoinItem = NSMenuItem(title: NSLocalizedString("Join Other Network..."))
    private let createNetworkItem = NSMenuItem(title: NSLocalizedString("Create Network..."))
    private let networkPanelItem = NSMenuItem(title: NSLocalizedString("Open Network Preferences..."))

    private let aboutItem = NSMenuItem(title: NSLocalizedString("About HeliPort"))
    private let checkUpdateItem = NSMenuItem(title: NSLocalizedString("Check for Updates..."))
    private let quitSeparator = NSMenuItem.separator()
    private let quitItem = NSMenuItem(title: NSLocalizedString("Quit HeliPort"),
                                      action: #selector(clickMenuItem(_:)), keyEquivalent: "q")

    private let toggleLaunchItem = NSMenuItem(
        title: NSLocalizedString("Launch At Login"),
        action: #selector(clickMenuItem(_:))
    )

    // MARK: - WiFi connected items

    let disconnectItem = NSMenuItem(
        title: NSLocalizedString("Disconnect from: ") + "(null)",
        action: #selector(disassociateSSID(_:)))
    private let ipAddresssItem = NSMenuItem(title: NSLocalizedString("    IP Address: ") + "(null)")
    private let routerItem = NSMenuItem(title: NSLocalizedString("    Router: ") + "(null)")
    private let internetItem = NSMenuItem(title: NSLocalizedString("    Internet: ") + "(null)")
    private let securityItem = NSMenuItem(title: NSLocalizedString("    Security: ") + "(null)")
    private let bssidItem = NSMenuItem(title: NSLocalizedString("    BSSID: ") + "(null)")
    private let channelItem = NSMenuItem(title: NSLocalizedString("    Channel: ") + "(null)")
    private let countryCodeItem = NSMenuItem(title: NSLocalizedString("    Country Code: ") + "(null)")
    private let rssiItem = NSMenuItem(title: NSLocalizedString("    RSSI: ") + "(null)")
    private let noiseItem = NSMenuItem(title: NSLocalizedString("    Noise: ") + "(null)")
    private let txRateItem = NSMenuItem(title: NSLocalizedString("    Tx Rate: ") + "(null)")
    private let phyModeItem = NSMenuItem(title: NSLocalizedString("    PHY Mode: ") + "(null)")
    private let mcsIndexItem = NSMenuItem(title: NSLocalizedString("    MCS Index: ") + "(null)")
    private let nssItem = NSMenuItem(title: NSLocalizedString("    NSS: ") + "(null)")

    // - MARK: Init

    init() {
        super.init(title: "")
        minimumWidth = CGFloat(286.0)
        delegate = self
        setupMenuHeaderAndFooter()
        getDeviceInfo()

        DispatchQueue.global(qos: .default).async {
            self.updateStatus()
            self.updateNetworkList()

            self.isAutoLaunch = LoginItemManager.isEnabled()

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

        addClickItem(enableLoggingItem)
        addClickItem(createReportItem)
        addClickItem(diagnoseItem)

        addItem(hardwareInfoSeparator)

        addItem(statusItem)
        addItem(switchItem)
        switchItem.target = self
        addItem(NSMenuItem.separator())

        headerLength = items.count

        for _ in 0..<maxNetworkListLength {
            networkItemList.append(addNetworkItemPlaceholder())
        }

        insertItem(disconnectItem, at: headerLength + 1)
        disconnectItem.target = self
        insertItem(ipAddresssItem, at: headerLength + 2)
        insertItem(routerItem, at: headerLength + 3)
        insertItem(internetItem, at: headerLength + 4)
        insertItem(securityItem, at: headerLength + 5)
        insertItem(bssidItem, at: headerLength + 6)
        insertItem(channelItem, at: headerLength + 7)
        insertItem(countryCodeItem, at: headerLength + 8)
        insertItem(rssiItem, at: headerLength + 9)
        insertItem(noiseItem, at: headerLength + 10)
        insertItem(txRateItem, at: headerLength + 11)
        insertItem(phyModeItem, at: headerLength + 12)
        insertItem(mcsIndexItem, at: headerLength + 13)
        insertItem(nssItem, at: headerLength + 14)

        addItem(networkItemListSeparator)

        addClickItem(manuallyJoinItem)
        addClickItem(createNetworkItem)
        addClickItem(networkPanelItem)

        addItem(NSMenuItem.separator())

        addClickItem(toggleLaunchItem)
        addClickItem(checkUpdateItem)
        addClickItem(aboutItem)

        addItem(quitSeparator)
        addClickItem(quitItem)
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
            self.updateNetworkInfo()
            self.updateNetworkList()
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
    }

    func menuDidClose(_ menu: NSMenu) {
        networkListUpdateTimer?.invalidate()
    }

    // - MARK: Actions

    private func addClickItem(_ item: NSMenuItem) {
        item.target = self
        item.action = #selector(clickMenuItem(_:))
        addItem(item)
    }

    private func getDeviceInfo() {
        DispatchQueue.global(qos: .background).async {
            var bsdName = NSLocalizedString("Unavailable")
            var macAddr = NSLocalizedString("Unavailable")
            var itlwmVer = NSLocalizedString("Unavailable")
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
                self.bsdItem.title = NSLocalizedString("Interface Name: ") + bsdName
                self.macItem.title = NSLocalizedString("Address: ") + macAddr
                self.itlwmVerItem.title = NSLocalizedString("Version: ") + itlwmVer
            }

            // If not connected, try to connect saved networks
            var stationInfo = station_info_t()
            var state: UInt32 = 0
            var power: Bool = false
            get_power_state(&power)
            if get_80211_state(&state) && power &&
                (state != ITL80211_S_RUN.rawValue || get_station_info(&stationInfo) != KERN_SUCCESS) {
                NetworkManager.connectSavedNetworks()
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
            networkInfo: NetworkInfo(ssid: "placeholder")
        )
        guard let view = item.view as? WifiMenuItemView else {
            return item
        }
        view.translatesAutoresizingMaskIntoConstraints = false
        guard let supView = view.superview else {
            return item
        }
        view.leadingAnchor.constraint(equalTo: supView.leadingAnchor).isActive = true
        view.topAnchor.constraint(equalTo: supView.topAnchor).isActive = true
        view.trailingAnchor.constraint(greaterThanOrEqualTo: supView.trailingAnchor).isActive = true
        view.visible = false
        return item
    }

    // - MARK: Action handlers

    @objc private func clickMenuItem(_ sender: NSMenuItem) {
        Log.debug("Clicked \(sender.title)")

        switch sender.title {
        case NSLocalizedString("Turn Wi-Fi On"):
            power_on()
        case NSLocalizedString("Turn Wi-Fi Off"):
            power_off()
        case NSLocalizedString("Join Other Network..."):
            let joinPop = JoinPopWindow()
            joinPop.show()
        case NSLocalizedString("Create Network..."):
            let alert = Alert(text: NSLocalizedString("FUNCTION NOT IMPLEMENTED"))
            alert.show()
        case NSLocalizedString("Open Network Preferences..."):
            NSWorkspace.shared.openFile("/System/Library/PreferencePanes/Network.prefPane")
        case NSLocalizedString("Check for Updates..."):
            heliPortUpdater.checkForUpdates(self)
        case NSLocalizedString("Launch At Login"):
            LoginItemManager.setStatus(enabled: LoginItemManager.isEnabled() ? false : true)
            isAutoLaunch = LoginItemManager.isEnabled()
        case NSLocalizedString("About HeliPort"):
            NSApplication.shared.orderFrontStandardAboutPanel()
            NSApplication.shared.activate(ignoringOtherApps: true)
        case NSLocalizedString("Quit HeliPort"):
            NSApp.terminate(nil)
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
                self.isNetworkCardAvailable = get_power_ret
                self.status = itl_80211_state(rawValue: status)
                self.updateNetworkInfo()
            }
        }
    }

    @objc private func updateNetworkInfo() {
        guard isNetworkCardEnabled else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            var disconnectName = NSLocalizedString("Unavailable")
            var ipAddr = NSLocalizedString("Unavailable")
            var routerAddr = NSLocalizedString("Unavailable")
            var internet = NSLocalizedString("Unavailable")
            var security = NSLocalizedString("Unavailable")
            var bssid = NSLocalizedString("Unavailable")
            var channel = NSLocalizedString("Unavailable")
            var countryCode = NSLocalizedString("Unavailable")
            var rssi = NSLocalizedString("Unavailable")
            var noise = NSLocalizedString("Unavailable")
            var txRate = NSLocalizedString("Unavailable")
            var phyMode = NSLocalizedString("Unavailable")
            var mcsIndex = NSLocalizedString("Unavailable")
            var nss = NSLocalizedString("Unavailable")
            self.isNetworkConnected = false
            var staInfo = station_info_t()
            if self.status == ITL80211_S_RUN && get_station_info(&staInfo) == KERN_SUCCESS {
                self.isNetworkConnected = true
                let bsd = String(self.bsdItem.title)
                    .replacingOccurrences(of: NSLocalizedString("Interface Name: "),
                                          with: "",
                                          options: .regularExpression,
                                          range: nil)
                let ipAddress = NetworkManager.getLocalAddress(bsd: bsd)
                let routerAddress = NetworkManager.getRouterAddress(bsd: bsd)
                let isReachable = NetworkManager.isReachable()
                disconnectName = String(cString: &staInfo.ssid.0)
                ipAddr = ipAddress ?? NSLocalizedString("Unknown")
                routerAddr = routerAddress ?? NSLocalizedString("Unknown")
                internet = NSLocalizedString(isReachable ? "Reachable" : "Unreachable")
                security = NSLocalizedString("Unknown")
                bssid = String(format: "%02x:%02x:%02x:%02x:%02x:%02x",
                               staInfo.bssid.0,
                               staInfo.bssid.1,
                               staInfo.bssid.2,
                               staInfo.bssid.3,
                               staInfo.bssid.4,
                               staInfo.bssid.5
                )
                channel = String(staInfo.channel) + " (" +
                    (staInfo.channel <= 14 ? "2.4 GHz" : "5 GHz") + ", " +
                "\(staInfo.band_width) MHz)"
                countryCode = NSLocalizedString("Unknown")
                rssi = String(staInfo.rssi) + " dBm"
                noise = String(staInfo.noise) + " dBm"
                txRate = String(staInfo.rate) + " Mbps"
                phyMode = staInfo.op_mode.description
                mcsIndex = String(staInfo.cur_mcs)
                nss = NSLocalizedString("Unknown")
            }
            DispatchQueue.main.async {
                self.disconnectItem.title = NSLocalizedString("Disconnect from: ") + disconnectName
                self.ipAddresssItem.title = NSLocalizedString("    IP Address: ") + ipAddr
                self.routerItem.title = NSLocalizedString("    Router: ") + routerAddr
                self.internetItem.title = NSLocalizedString("    Internet: ") + internet
                self.securityItem.title = NSLocalizedString("    Security: ") + security
                self.bssidItem.title = NSLocalizedString("    BSSID: ") + bssid
                self.channelItem.title = NSLocalizedString("    Channel: ") + channel
                self.countryCodeItem.title = NSLocalizedString("    Country Code: ") + countryCode
                self.rssiItem.title = NSLocalizedString("    RSSI: ") + rssi
                self.noiseItem.title = NSLocalizedString("    Noise: ") + noise
                self.txRateItem.title = NSLocalizedString("    Tx Rate: ") + txRate
                self.phyModeItem.title = NSLocalizedString("    PHY Mode: ") + phyMode
                self.mcsIndexItem.title = NSLocalizedString("    MCS Index: ") + mcsIndex
                self.nssItem.title = NSLocalizedString("    NSS: ") + nss
                guard self.isNetworkCardEnabled,
                    let wifiItemView = self.networkItemList[0].view as? WifiMenuItemView else {
                    return
                }
                wifiItemView.visible = self.isNetworkConnected
                wifiItemView.connected = self.isNetworkConnected
                if self.isNetworkConnected {
                    self.isNetworkListEmpty = false
                    wifiItemView.networkInfo = NetworkInfo(
                        ssid: String(cString: &staInfo.ssid.0),
                        rssi: Int(staInfo.rssi)
                    )
                }
            }
        }
    }

    @objc private func updateNetworkList() {
        guard isNetworkCardEnabled else {
            return
        }

        NetworkManager.scanNetwork { networkList in
            self.isNetworkListEmpty = networkList.count == 0 && !self.isNetworkConnected
            var networkList = networkList
            for index in 1 ..< self.networkItemList.count {
                if let view = self.networkItemList[index].view as? WifiMenuItemView {
                    if networkList.count > 0 {
                        view.networkInfo = networkList.removeFirst()
                        view.visible = true
                    } else {
                        view.visible = false
                    }
                }
            }
        }
    }

    @objc func disassociateSSID(_ sender: NSMenuItem) {
        let ssid = String(sender.title)
            .replacingOccurrences(of: NSLocalizedString("Disconnect from: "), with: "",
                                  options: .regularExpression,
                                  range: nil
        )

        DispatchQueue.global().async {
            CredentialsManager.instance.setAutoJoin(ssid, false)
            dis_associate_ssid(ssid)
            print("disconnected from \(ssid)")
        }
    }
}
