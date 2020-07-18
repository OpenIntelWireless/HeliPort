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

            statusItem.title = NSLocalizedString(status.description, comment: "")

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
                /*
                 * Hide top items if the Options button is not pressed.
                 * TODO: idx 3, 4, 5 have not been implemented
                 * 3: Enable Wi-Fi Logging
                 * 4: Create Diagnostics Report...
                 * 5: Open Wi-Fi Diagnostics...
                 */
                if idx == 3 || idx == 4 || idx == 5 {
                    items[idx].isHidden = true
                    continue
                }
                items[idx].isHidden = !visible
            }

            for idx in 11...24 {
                /*
                 * Hide items for which when there is no Wi-Fi connection and
                 * Options button is not pressed.
                 * idx 15, 18, 24 have not been implemented in io_station_info
                 * 15: security
                 * 18: country code
                 * 24: NSS
                 */
                if idx == 15 || idx == 18 || idx == 24 {
                    items[idx].isHidden = true
                    continue
                }
                items[idx].isHidden = !(visible && status == ITL80211_S_RUN)
            }

            // Create Network... has not been implemented in itlwm
            items[items.count - 8].isHidden = true

            /*
             * Hide bottom items if the Options button is not pressed:
             * item.count - 1: Quit HeliPort
             * item.count - 2: NSMenuItem.separator()
             * item.count - 3: Check for Updates
             * item.count - 4: Launch at Login
             */
            for idx in 1...4 {
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

    private var isNetworkCardAvailable: Bool = true {
        willSet(newState) {
            if !newState {
                self.isNetworkCardEnabled = false
            }

            for inx in 6...9 {
                // TODO: Create Network... has not been implemented in itlwm
                if inx == 8 {
                    continue
                }

                /*
                 * Hide items that cannot be used while card is not working
                 * items.count - 6: Open Network Preferences...
                 * items.count - 7: Create Network...
                 * items.count - 8: Join Other Network...
                 * items.count - 9: networkItemListSeparator
                 */
                items[items.count - inx].isHidden = !newState
            }
        }
    }

    private var isNetworkCardEnabled: Bool = false {
        willSet(newState) {
            statusItem.title = NSLocalizedString(newState ? "Wi-Fi: On" : "Wi-Fi: Off", comment: "")
            switchItem.title = NSLocalizedString(newState ? "Turn Wi-Fi Off" : "Turn Wi-Fi On", comment: "")
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

    private let statusItem = NSMenuItem(title: NSLocalizedString("Wi-Fi: Status unavailable", comment: ""))
    private let switchItem = NSMenuItem(
        title: NSLocalizedString("Turn Wi-Fi On", comment: ""),
        action: #selector(clickMenuItem(_:))
    )
    private let bsdItem = NSMenuItem(title: NSLocalizedString("Interface Name: ", comment: "") + "(null)")
    private let macItem = NSMenuItem(title: NSLocalizedString("Address: ", comment: "") + "(null)")
    private let itlwmVerItem = NSMenuItem(title: NSLocalizedString("Version: ", comment: "") + "(null)")

    private let toggleLaunchItem = NSMenuItem(
        title: NSLocalizedString("Launch At Login", comment: ""),
        action: #selector(clickMenuItem(_:))
    )

    // MARK: - WiFi connected items

    let disconnectItem = NSMenuItem(
        title: NSLocalizedString("Disconnect from: ", comment: "") + "(null)",
        action: #selector(disassociateSSID(_:)))
    private let ipAddresssItem = NSMenuItem(title: NSLocalizedString("    IP Address: ", comment: "") + "(null)")
    private let routerItem = NSMenuItem(title: NSLocalizedString("    Router: ", comment: "") + "(null)")
    private let internetItem = NSMenuItem(title: NSLocalizedString("    Internet: ", comment: "") + "(null)")
    private let securityItem = NSMenuItem(title: NSLocalizedString("    Security: ", comment: "") + "(null)")
    private let bssidItem = NSMenuItem(title: NSLocalizedString("    BSSID: ", comment: "") + "(null)")
    private let channelItem = NSMenuItem(title: NSLocalizedString("    Channel: ", comment: "") + "(null)")
    private let countryCodeItem = NSMenuItem(title: NSLocalizedString("    Country Code: ", comment: "") + "(null)")
    private let rssiItem = NSMenuItem(title: NSLocalizedString("    RSSI: ", comment: "") + "(null)")
    private let noiseItem = NSMenuItem(title: NSLocalizedString("    Noise: ", comment: "") + "(null)")
    private let txRateItem = NSMenuItem(title: NSLocalizedString("    Tx Rate: ", comment: "") + "(null)")
    private let phyModeItem = NSMenuItem(title: NSLocalizedString("    PHY Mode: ", comment: "") + "(null)")
    private let mcsIndexItem = NSMenuItem(title: NSLocalizedString("    MCS Index: ", comment: "") + "(null)")
    private let nssItem = NSMenuItem(title: NSLocalizedString("    NSS: ", comment: "") + "(null)")

    // - MARK: Init

    init() {
        super.init(title: "")
        minimumWidth = CGFloat(286.0)
        delegate = self
        setupMenuHeaderAndFooter()
        getDeviceInfo()

        DispatchQueue.global(qos: .default).async {
            var powerState: Bool = false
            let get_power_ret = get_power_state(&powerState)
            DispatchQueue.main.async {
                if get_power_ret {
                    self.isNetworkCardEnabled = powerState
                    self.updateNetworkList()
                }
            }

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

        addClickItem(title: NSLocalizedString("Enable Wi-Fi Logging", comment: ""))
        addClickItem(title: NSLocalizedString("Create Diagnostics Report...", comment: ""))
        addClickItem(title: NSLocalizedString("Open Wireless Diagnostics...", comment: ""))

        addItem(NSMenuItem.separator())

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

        addClickItem(title: NSLocalizedString("Join Other Network...", comment: ""))
        addClickItem(title: NSLocalizedString("Create Network...", comment: ""))
        addClickItem(title: NSLocalizedString("Open Network Preferences...", comment: ""))

        addItem(NSMenuItem.separator())

        addClickItem(title: NSLocalizedString("About HeliPort", comment: ""))
        addItem(toggleLaunchItem)
        toggleLaunchItem.target = self
        addClickItem(title: NSLocalizedString("Check for Updates...", comment: ""))

        addItem(NSMenuItem.separator())

        addClickItem(title: NSLocalizedString("Quit HeliPort", comment: ""), keyEquivalent: "q")
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

            // If not connected, try to connect saved networks
            var stationInfo = station_info_t()
            var state: UInt32 = 0
            if get_80211_state(&state) &&
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
            networkInfo: NetworkInfo(
                ssid: "placeholder",
                connected: false,
                rssi: 0
            )
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
            alert.alertStyle = .critical
            alert.runModal()
        case NSLocalizedString("Open Network Preferences...", comment: ""):
            NSWorkspace.shared.openFile("/System/Library/PreferencePanes/Network.prefPane")
        case NSLocalizedString("Check for Updates...", comment: ""):
            heliPortUpdater.checkForUpdates(self)
        case NSLocalizedString("Launch At Login", comment: ""):
            LoginItemManager.setStatus(enabled: LoginItemManager.isEnabled() ? false : true)
            isAutoLaunch = LoginItemManager.isEnabled()
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
                self.isNetworkCardAvailable = get_power_ret
                self.status = itl_80211_state(rawValue: status)
            }
        }
    }

    @objc private func updateNetworkInfo() {
        guard isNetworkCardEnabled else {
            return
        }

        DispatchQueue.global(qos: .background).async {
            var disconnectName = NSLocalizedString("Unavailable", comment: "")
            var ipAddr = NSLocalizedString("Unavailable", comment: "")
            var routerAddr = NSLocalizedString("Unavailable", comment: "")
            var internet = NSLocalizedString("Unavailable", comment: "")
            var security = NSLocalizedString("Unavailable", comment: "")
            var bssid = NSLocalizedString("Unavailable", comment: "")
            var channel = NSLocalizedString("Unavailable", comment: "")
            var countryCode = NSLocalizedString("Unavailable", comment: "")
            var rssi = NSLocalizedString("Unavailable", comment: "")
            var noise = NSLocalizedString("Unavailable", comment: "")
            var txRate = NSLocalizedString("Unavailable", comment: "")
            var phyMode = NSLocalizedString("Unavailable", comment: "")
            var mcsIndex = NSLocalizedString("Unavailable", comment: "")
            var nss = NSLocalizedString("Unavailable", comment: "")
            var staInfo = station_info_t()
            if self.status == ITL80211_S_RUN && get_station_info(&staInfo) == KERN_SUCCESS {
                let bsd = String(self.bsdItem.title)
                    .replacingOccurrences(of: NSLocalizedString("Interface Name: ", comment: ""),
                                          with: "",
                                          options: .regularExpression,
                                          range: nil)
                let ipAddress = NetworkManager.getLocalAddress(bsd: bsd)
                let routerAddress = NetworkManager.getRouterAddress(bsd: bsd)
                let isReachable = NetworkManager.isReachable()
                disconnectName = String(cString: &staInfo.ssid.0)
                ipAddr = ipAddress ?? NSLocalizedString("Unknown", comment: "")
                routerAddr = routerAddress ?? NSLocalizedString("Unknown", comment: "")
                internet = NSLocalizedString(isReachable ? "Reachable" : "Unreachable", comment: "")
                security = NSLocalizedString("Unknown", comment: "")
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
                countryCode = NSLocalizedString("Unknown", comment: "")
                rssi = String(staInfo.rssi) + " dBm"
                noise = String(staInfo.noise) + " dBm"
                txRate = String(staInfo.rate) + " Mbps"
                phyMode = staInfo.op_mode.description
                mcsIndex = String(staInfo.cur_mcs)
                nss = NSLocalizedString("Unknown", comment: "")
            }
            DispatchQueue.main.async {
                self.disconnectItem.title = NSLocalizedString("Disconnect from: ", comment: "") + disconnectName
                self.ipAddresssItem.title = NSLocalizedString("    IP Address: ", comment: "") + ipAddr
                self.routerItem.title = NSLocalizedString("    Router: ", comment: "") + routerAddr
                self.internetItem.title = NSLocalizedString("    Internet: ", comment: "") + internet
                self.securityItem.title = NSLocalizedString("    Security: ", comment: "") + security
                self.bssidItem.title = NSLocalizedString("    BSSID: ", comment: "") + bssid
                self.channelItem.title = NSLocalizedString("    Channel: ", comment: "") + channel
                self.countryCodeItem.title = NSLocalizedString("    Country Code: ", comment: "") + countryCode
                self.rssiItem.title = NSLocalizedString("    RSSI: ", comment: "") + rssi
                self.noiseItem.title = NSLocalizedString("    Noise: ", comment: "") + noise
                self.txRateItem.title = NSLocalizedString("    Tx Rate: ", comment: "") + txRate
                self.phyModeItem.title = NSLocalizedString("    PHY Mode: ", comment: "") + phyMode
                self.mcsIndexItem.title = NSLocalizedString("    MCS Index: ", comment: "") + mcsIndex
                self.nssItem.title = NSLocalizedString("    NSS: ", comment: "") + nss
            }
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
                if let view = self.networkItemList[index].view as? WifiMenuItemView {
                    if networkList.count > 0 {
                        view.networkInfo = networkList.removeFirst()
                        view.visible = true
                    } else {
                        view.visible = false
                    }
                }
            }
            self.updateNetworkInfo()
        }
    }

    @objc func disassociateSSID(_ sender: NSMenuItem) {
        let ssid = String(sender.title)
            .replacingOccurrences(of: NSLocalizedString("Disconnect from: ", comment: ""), with: "",
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
