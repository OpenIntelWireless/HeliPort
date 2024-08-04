//
//  StatusMenuLegacy.swift
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

import Cocoa

final class StatusMenuLegacy: StatusMenuBase, StatusMenuItems {

    // - MARK: Menu items

    private let statusItem = NSMenuItem(title: .Legacy.statusUnavailable)
    private let switchItem = NSMenuItem(title: .Legacy.turnWiFiOn,
                                        action: #selector(clickMenuItem(_:)))
    private let disconnectItem = NSMenuItem(title: .Legacy.disconnectNet + "(null)",
                                            action: #selector(disassociateSSID(_:)))

    private let manuallyJoinItem = NSMenuItem(title: .Legacy.joinNetworks)
    private let createNetworkItem = NSMenuItem(title: .Legacy.createNetwork)
    private let networkPanelItem = NSMenuItem(title: .Legacy.openNetworkPrefs)

    lazy var enabledNetworkCardItems: [NSMenuItem] = [
        createNetworkItem,
        manuallyJoinItem
    ]

    lazy var stationInfoItems: [NSMenuItem] = [
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

    lazy var hiddenItems: [NSMenuItem] = [
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
        aboutItem,
        quitItem
    ]

    lazy var notImplementedItems: [NSMenuItem] = [
        enableLoggingItem,
        diagnoseItem,

        securityItem,
        countryCodeItem,
        nssItem,

        createNetworkItem
    ]

    override var isNetworkListEmpty: Bool {
        willSet(empty) {
            super.isNetworkListEmpty = empty
            networkItemListSeparator.isHidden = empty
            guard empty else { return }
            networkItemList.forEach { $0.isHidden = true }
        }
    }

    override var isNetworkCardEnabled: Bool {
        willSet(newState) {
            statusItem.title = newState ? .Legacy.wifiOn : .Legacy.wifiOff
            switchItem.title = newState ? .Legacy.turnWiFiOff : .Legacy.turnWiFiOn
            super.isNetworkCardEnabled = newState
        }
    }

    private var networkItemList = [NSMenuItem]()

    // - MARK: Init

    override init() {
        super.init()
        minimumWidth = 286
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupMenu() {
        addKeyValueItem(bsdItem)
        addKeyValueItem(macItem)
        addKeyValueItem(itlwmVerItem)

        addClickItem(enableLoggingItem)
        addClickItem(createReportItem)
        addClickItem(diagnoseItem)

        addItem(hardwareInfoSeparator)

        addItem(statusItem)
        addItem(switchItem)
        switchItem.target = self
        addItem(NSMenuItem.separator())

        _ = addNetworkItem(currentNetworkItem)

        addItem(disconnectItem)
        disconnectItem.target = self

        stationInfoItems.filter { $0 != disconnectItem }
                        .forEach { addKeyValueItem($0) }

        headerLength = items.count
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

    func addKeyValueItem(_ item: NSMenuItem) {
        item.representedObject = item.title
        setValueForItem(item, value: "(null)")
        addItem(item)
    }

    // - MARK: Menu Updates

    func setValueForItem(_ item: NSMenuItem, value: String) {
        guard let key = item.representedObject as? String else { return }
        item.title = key + value
    }

    func updateNetworkList() {
        guard isNetworkCardEnabled else { return }

        NetworkManager.scanNetwork { networkList in
            self.isNetworkListEmpty = networkList.count == 0 && !self.isNetworkConnected
            if networkList.count > MAX_NETWORK_LIST_LENGTH {
                Log.error("Number of scanned networks (\(networkList.count))" +
                            " exceeds maximum (\(MAX_NETWORK_LIST_LENGTH))")
            }

            let staInfo: NetworkInfo? = (self.isNetworkConnected
                                         ? (self.currentNetworkItem.view as? WifiMenuItemView)?.networkInfo
                                         : nil)

            self.processNetworkList(from: networkList, to: &self.networkItemList,
                                    insertAt: self.headerLength, staInfo)
        }
    }

    func toggleWIFI() {
        DispatchQueue.main.async {
            self.clickMenuItem(self.switchItem)
        }
    }

    @objc func disassociateSSID(_ sender: NSMenuItem) {
        guard let ssid = sender.representedObject as? String else { return }
        DispatchQueue.global().async {
            CredentialsManager.instance.setAutoJoin(ssid, false)
            dis_associate_ssid(ssid)
            Log.debug("Disconnected from \(ssid)")
        }
    }

    // - MARK: Overrides

    override func addNetworkItem(_ item: NSMenuItem = HPMenuItem(highlightable: true),
                                 insertAt: Int? = nil,
                                 hidden: Bool = false,
                                 networkInfo: NetworkInfo = NetworkInfo(ssid: "placeholder")) -> NSMenuItem {
        item.view = WifiMenuItemViewLegacy(networkInfo: networkInfo)

        if let view = item.view as? WifiMenuItemView, let supView = view.superview {
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: supView.leadingAnchor),
                view.topAnchor.constraint(equalTo: supView.topAnchor),
                view.trailingAnchor.constraint(greaterThanOrEqualTo: supView.trailingAnchor)
            ])
        }

        return super.addNetworkItem(item, insertAt: insertAt, hidden: hidden, networkInfo: networkInfo)
    }

    override func setCurrentNetworkItem(with info: StatusMenuBase.StationInfo) {
        super.setCurrentNetworkItem(with: info)
        guard isNetworkConnected, let ssid = info.ssid else { return }

        DispatchQueue.global(qos: .background).async {
#if !DEBUG
            let autoJoin = CredentialsManager.instance.getStorageFromSsid(ssid)?.autoJoin ?? false
#else
            let autoJoin = false
#endif
            let hidden = autoJoin && !self.showAllOptions
            DispatchQueue.main.async {
                if !hidden {
                    self.disconnectItem.representedObject = ssid
                    self.disconnectItem.title = .Legacy.disconnectNet + ssid
                }
                self.disconnectItem.isHidden = hidden
            }
        }
    }
}
