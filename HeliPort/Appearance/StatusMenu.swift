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

    // One instance at a time
    private var preferenceWindow: PrefsWindow?

    private var status: itl_80211_state = ITL80211_S_INIT {
        didSet {
            /* Only allow if network card is enabled or if the network card does not load
             either due to itlwm not loaded or just not able to receive info
             This prevents cards that are working but are "off" to not change the
             Status from "WiFi off" to another status. i.e "WiFi: on". */
            guard isNetworkCardEnabled || !isNetworkCardAvailable else { return }

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
                        guard isReachable else { StatusBarIcon.warning(); return }
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
                diagnoseItem,

                securityItem,
                countryCodeItem,
                nssItem,

                createNetworkItem
            ]

            hiddenItems.forEach { $0.isHidden = !visible }
            enabledNetworkCardItems.forEach { $0.isHidden = !isNetworkCardAvailable }
            connectedNetworkInfoItems.forEach { $0.isHidden = !(visible && status == ITL80211_S_RUN) }
            notImplementedItems.forEach { $0.isHidden = true }
        }
    }

    private var isNetworkConnected: Bool = false

    private var isNetworkListEmpty: Bool = true {
        willSet(empty) {
            networkItemListSeparator.isHidden = empty
            guard empty else { return }

            for item in self.networkItemList {
                (item.view as? WifiMenuItemView)?.visible = false
            }
        }
    }

    private var isNetworkCardAvailable: Bool = true {
        willSet(newState) {
            if !newState { self.isNetworkCardEnabled = false }
        }
    }

    private var isNetworkCardEnabled: Bool = false {
        willSet(newState) {
            statusItem.title = newState ? .wifiOn : .wifiOff
            switchItem.title = newState ? .turnWiFiOff : .turnWiFiOn
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

    private let statusItem = NSMenuItem(title: .statusUnavailable)
    private let switchItem = NSMenuItem(
        title: .turnWiFiOn,
        action: #selector(clickMenuItem(_:))
    )
    private let bsdItem = NSMenuItem(title: .interfaceName + "(null)")
    private let macItem = NSMenuItem(title: .macAddress + "(null)")
    private let itlwmVerItem = NSMenuItem(title: .itlwmVer + "(null)")

    private let enableLoggingItem = NSMenuItem(title: .enableWiFiLog)
    private let createReportItem = NSMenuItem(title: .createReport)
    private let diagnoseItem = NSMenuItem(title: .openDiagnostics)
    private let hardwareInfoSeparator = NSMenuItem.separator()

    private var networkItemList = [NSMenuItem]()
    private let maxNetworkListLength = MAX_NETWORK_LIST_LENGTH
    private let networkItemListSeparator: NSMenuItem = {
        let networkItemListSeparator =  NSMenuItem.separator()
        networkItemListSeparator.isHidden = true
        return networkItemListSeparator
    }()

    private let manuallyJoinItem = NSMenuItem(title: .joinNetworks)
    private let createNetworkItem = NSMenuItem(title: .createNetwork)
    private let networkPanelItem = NSMenuItem(title: .openNetworkPrefs)

    private let aboutItem = NSMenuItem(title: .aboutHeliport)
    private let checkUpdateItem = NSMenuItem(title: .checkUpdates)
    private let quitSeparator = NSMenuItem.separator()
    private let quitItem = NSMenuItem(title: .quitHeliport,
                                      action: #selector(clickMenuItem(_:)), keyEquivalent: "q")

    private let toggleLaunchItem = NSMenuItem(
        title: .launchLogin,
        action: #selector(clickMenuItem(_:))
    )

    // MARK: - WiFi connected items

    let disconnectItem = NSMenuItem(
        title: .disconnectNet + "(null)",
        action: #selector(disassociateSSID(_:)))
    private let ipAddresssItem = NSMenuItem(title: .ipAddr + "(null)")
    private let routerItem = NSMenuItem(title: .routerStr + "(null)")
    private let internetItem = NSMenuItem(title: .internetStr + "(null)")
    private let securityItem = NSMenuItem(title: .securityStr + "(null)")
    private let bssidItem = NSMenuItem(title: .bssidStr + "(null)")
    private let channelItem = NSMenuItem(title: .channelStr + "(null)")
    private let countryCodeItem = NSMenuItem(title: .countryCodeStr + "(null)")
    private let rssiItem = NSMenuItem(title: .rssiStr + "(null)")
    private let noiseItem = NSMenuItem(title: .noiseStr + "(null)")
    private let txRateItem = NSMenuItem(title: .txRateStr + "(null)")
    private let phyModeItem = NSMenuItem(title: .phyModeStr + "(null)")
    private let mcsIndexItem = NSMenuItem(title: .mcsStr + "(null)")
    private let nssItem = NSMenuItem(title: .nssStr + "(null)")

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
        networkItemList.forEach { ($0.view as? WifiMenuItemView)?.checkHighlight() }
    }

    func menuWillOpen(_ menu: NSMenu) {

        showAllOptions = (NSApp.currentEvent?.modifierFlags.contains(.option))!

        DispatchQueue.global(qos: .default).async {
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
            var bsdName: String = .unavailable
            var macAddr: String = .unavailable
            var itlwmVer: String = .unavailable
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
                self.bsdItem.title = .interfaceName + bsdName
                self.macItem.title = .macAddress + macAddr
                self.itlwmVerItem.title = .itlwmVer + itlwmVer
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
        case .createReport:
            // Disable while bug report is being genetated, if autoenable == true, NSMenu ignores isEnable
            createReportItem.action = nil
            DispatchQueue.global(qos: .background).async {
                BugReporter.generateBugReport()
                DispatchQueue.main.async {
                    // Enable after generating report is finished
                    self.createReportItem.action = #selector(self.clickMenuItem(_:))
                }
            }
        case .turnWiFiOn:
            power_on()
        case .turnWiFiOff:
            power_off()
        case .joinNetworks:
            let joinPop = JoinPopWindow()
            joinPop.show()
        case .createNetwork:
            let alert = Alert(text: .notImplemented)
            alert.show()
        case .openNetworkPrefs:
            preferenceWindow?.close()
            preferenceWindow = PrefsWindow()
            preferenceWindow?.show()
        case .checkUpdates:
            heliPortUpdater.checkForUpdates(self)
        case .launchLogin:
            LoginItemManager.setStatus(enabled: LoginItemManager.isEnabled() ? false : true)
            isAutoLaunch = LoginItemManager.isEnabled()
        case .aboutHeliport:
            NSApplication.shared.orderFrontStandardAboutPanel()
            NSApplication.shared.activate(ignoringOtherApps: true)
        case .quitHeliport:
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
            let get_state_ret = get_80211_state(&status)

            DispatchQueue.main.async {
                if get_power_ret && get_state_ret {
                    self.isNetworkCardEnabled = powerState
                } else {
                    Log.error("Failed get card state")
                }
                self.isNetworkCardAvailable = get_power_ret
                self.status = itl_80211_state(rawValue: status)
                self.updateNetworkInfo()
            }
        }
    }

    @objc private func updateNetworkInfo() {
        guard isNetworkCardEnabled else { return }

        DispatchQueue.global(qos: .background).async {
            var disconnectName: String = .unavailable
            var ipAddr: String = .unavailable
            var routerAddr: String = .unavailable
            var internet: String = .unavailable
            var security: String = .unavailable
            var bssid: String = .unavailable
            var channel: String = .unavailable
            var countryCode: String = .unavailable
            var rssi: String = .unavailable
            var noise: String = .unavailable
            var txRate: String = .unavailable
            var phyMode: String = .unavailable
            var mcsIndex: String = .unavailable
            var nss: String = .unavailable
            self.isNetworkConnected = false
            var staInfo = station_info_t()
            if self.status == ITL80211_S_RUN && get_station_info(&staInfo) == KERN_SUCCESS {
                self.isNetworkConnected = true
                let bsd = String(self.bsdItem.title).replacingOccurrences(of: String.interfaceName, with: "",
                                                                          options: .regularExpression, range: nil)
                let ipAddress = NetworkManager.getLocalAddress(bsd: bsd)
                let routerAddress = NetworkManager.getRouterAddress(bsd: bsd)
                let isReachable = NetworkManager.isReachable()
                disconnectName = String(cString: &staInfo.ssid.0)
                ipAddr = ipAddress ?? .unknown
                routerAddr = routerAddress ?? .unknown
                internet = isReachable ? .reachable : .unreachable
                security = .unknown
                bssid = String(format: "%02x:%02x:%02x:%02x:%02x:%02x",
                               staInfo.bssid.0,
                               staInfo.bssid.1,
                               staInfo.bssid.2,
                               staInfo.bssid.3,
                               staInfo.bssid.4,
                               staInfo.bssid.5
                )
                channel = "\(staInfo.channel) (\(staInfo.channel <= 14 ? 2.4 : 5) GHz, \(staInfo.band_width) MHz)"
                countryCode = .unknown
                rssi = "\(staInfo.rssi) dBm"
                noise = "\(staInfo.noise) dBm"
                txRate = "\(staInfo.rate) Mbps"
                phyMode = staInfo.op_mode.description
                mcsIndex = String(staInfo.cur_mcs)
                nss = .unknown
            }
            DispatchQueue.main.async {
                self.disconnectItem.title = .disconnectNet + disconnectName
                self.ipAddresssItem.title = .ipAddr + ipAddr
                self.routerItem.title = .routerStr + routerAddr
                self.internetItem.title = .internetStr + internet
                self.securityItem.title = .securityStr + security
                self.bssidItem.title = .bssidStr + bssid
                self.channelItem.title = .channelStr + channel
                self.countryCodeItem.title = .countryCodeStr + countryCode
                self.rssiItem.title = .rssiStr + rssi
                self.noiseItem.title = .noiseStr + noise
                self.txRateItem.title = .txRateStr + txRate
                self.phyModeItem.title = .phyModeStr + phyMode
                self.mcsIndexItem.title = .mcsStr + mcsIndex
                self.nssItem.title = .nssStr + nss
                guard self.isNetworkCardEnabled,
                    let wifiItemView = self.networkItemList.first?.view as? WifiMenuItemView else { return }
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
        guard isNetworkCardEnabled else { return }

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
        let ssid = String(sender.title).replacingOccurrences(of: String.disconnectNet, with: "",
                                                             options: .regularExpression,
                                                             range: nil)
        DispatchQueue.global().async {
            CredentialsManager.instance.setAutoJoin(ssid, false)
            dis_associate_ssid(ssid)
            Log.debug("Disconnected from \(ssid)")
        }
    }
}

// MARK: Localized Strings

private extension String {
    static let notImplemented = NSLocalizedString("FUNCTION NOT IMPLEMENTED")
    static let unknown = NSLocalizedString("Unknown")
    static let unavailable = NSLocalizedString("Unavailable")
    static let statusUnavailable = NSLocalizedString("Wi-Fi: Status unavailable")
    static let turnWiFiOn = NSLocalizedString("Turn Wi-Fi On")
    static let turnWiFiOff = NSLocalizedString("Turn Wi-Fi Off")
    static let wifiOn = NSLocalizedString("Wi-Fi: On")
    static let wifiOff = NSLocalizedString("Wi-Fi: Off")
    static let interfaceName = NSLocalizedString("Interface Name: ")
    static let macAddress = NSLocalizedString("Address: ")
    static let itlwmVer = NSLocalizedString("Version: ")
    static let enableWiFiLog = NSLocalizedString("Enable Wi-Fi Logging")
    static let createReport = NSLocalizedString("Create Diagnostics Report...")
    static let openDiagnostics = NSLocalizedString("Open Wireless Diagnostics...")
    static let joinNetworks = NSLocalizedString("Join Other Network...")
    static let createNetwork = NSLocalizedString("Create Network...")
    static let openNetworkPrefs = NSLocalizedString("Open Network Preferences...")
    static let checkUpdates = NSLocalizedString("Check for Updates...")
    static let aboutHeliport = NSLocalizedString("About HeliPort")
    static let quitHeliport = NSLocalizedString("Quit HeliPort")
    static let launchLogin = NSLocalizedString("Launch At Login")
    static let disconnectNet = NSLocalizedString("Disconnect from: ")
    static let ipAddr = NSLocalizedString("    IP Address: ")
    static let routerStr = NSLocalizedString("    Router: ")
    static let internetStr = NSLocalizedString("    Internet: ")
    static let reachable = NSLocalizedString("Reachable")
    static let unreachable = NSLocalizedString("Unreachable")
    static let securityStr = NSLocalizedString("    Security: ")
    static let bssidStr = NSLocalizedString("    BSSID: ")
    static let channelStr = NSLocalizedString("    Channel: ")
    static let countryCodeStr = NSLocalizedString("    Country Code: ")
    static let rssiStr = NSLocalizedString("    RSSI: ")
    static let noiseStr = NSLocalizedString("    Noise: ")
    static let txRateStr = NSLocalizedString("    Tx Rate: ")
    static let phyModeStr = NSLocalizedString("    PHY Mode: ")
    static let mcsStr = NSLocalizedString("    MCS Index: ")
    static let nssStr = NSLocalizedString("    NSS: ")
}
