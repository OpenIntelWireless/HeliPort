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

    let networkListUpdatePeriod: Double = 10

    var headerLength: Int = 0
    var timer: Timer?
    var showAllOptions: Bool = false

    var statusItem: NSMenuItem?
    var networkItemList = [NSMenuItem]()
    let maxNetworkListLength = MAX_NETWORK_LIST_LENGTH
    var networkItemListSeparator: NSMenuItem?

    override init(title: String) {
        super.init(title: title)
        minimumWidth = CGFloat(285.0)
        delegate = self
        //autoenablesItems = false
        setupMenuHeaderAndFooter()
        updateNetworkList()
    }

    func setupMenuHeaderAndFooter() {
        addItem(withTitle: NSLocalizedString("Interface Name: en1", comment: ""), action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: NSLocalizedString("Address: aa:bb:cc:dd:ee:ff", comment: ""), action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: NSLocalizedString("Enable Wi-Fi Logging", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Create Diagnostics Report...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Open Wireless Diagnostics...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())

        statusItem = addItem(withTitle: NSLocalizedString("Unavaliable", comment: ""), action: nil, keyEquivalent: "")
        statusItem?.isEnabled = false
        addItem(withTitle: NSLocalizedString("Turn Wi-Fi Off", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())

        headerLength = items.count

        for _ in 1...maxNetworkListLength {
            networkItemList.append(addNetworkItemPlaceholder())
        }

        networkItemListSeparator = NSMenuItem.separator()
        networkItemListSeparator?.isHidden = true
        addItem(networkItemListSeparator!)

        addItem(withTitle: NSLocalizedString("Join Other Network...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Create Network...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Open Network Preferences...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Check for Updates...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("About HeliPort", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Quit HeliPort", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "Q").target = self
    }

    func menuWillOpen(_ menu: NSMenu) {

        showAllOptions = (NSApp.currentEvent?.modifierFlags.contains(.option))!

        let queue = DispatchQueue.global(qos: .default)
        queue.async {
            self.timer = Timer.scheduledTimer(timeInterval: self.networkListUpdatePeriod, target: self, selector: #selector(self.updateNetworkList), userInfo: nil, repeats: true)
            let currentRunLoop = RunLoop.current
            currentRunLoop.add(self.timer!, forMode: .common)
            currentRunLoop.run()
        }

        if showAllOptions {
            buildOptionMenu()
        } else {
            buildNormalMenu()
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        timer?.invalidate()
    }

    func buildNormalMenu() {
        for idx in 0...5 {
            items[idx].isHidden = true
        }
        for idx in 1...3 {
            items[items.count - idx].isHidden = true
        }
    }

    func buildOptionMenu() {
        for idx in 0...5 {
            items[idx].isHidden = false
        }
        for idx in 1...3 {
            items[items.count - idx].isHidden = false
        }
    }

    @objc func clickMenuItem(_ sender: NSMenuItem) {
        print(sender.title)
        switch sender.title {
        case NSLocalizedString("Turn Wi-Fi On", comment: ""):
            //items[6].title = NSLocalizedString("Wi-Fi: On", comment: "")
            //items[7].title = NSLocalizedString("Turn Wi-Fi Off", comment: "")
            StatusBarIcon.on()
        case NSLocalizedString("Turn Wi-Fi Off", comment: ""):
            //items[6].title = NSLocalizedString("Wi-Fi: Off", comment: "")
            //items[7].title = NSLocalizedString("Turn Wi-Fi On", comment: "")
            //timer?.invalidate()
            //timer = nil
            //StatusBarIcon.off()
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("FUNCTION NOT IMPLEMENTED", comment: "")
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        case NSLocalizedString("Join Other Network...", comment: ""):
            let joinPop = JoinPopWindow.init(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247), styleMask: .titled, backing: .buffered, defer: false)
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
            //let url = URL(string: "x-apple.systempreferences:com.apple.preference.network")!
            //NSWorkspace.shared.open(url)
        }
    }

    func addNetworkItemPlaceholder() -> NSMenuItem {
        let item = addItem(withTitle: "placeholder", action: #selector(clickMenuItem(_:)), keyEquivalent: "")
        item.view = WifiMenuItemView(networkInfo: NetworkInfo(ssid: "placeholder", connected: false, rssi: 0))
        guard let view = item.view as? WifiMenuItemView else {
            return item
        }
        view.hide()
        return item
    }

    @objc func updateNetworkList() {
        DispatchQueue.global(qos: .background).async {
            var statusText = NSLocalizedString("No Status Information Avaliable", comment: "")
            var platformInfo = platform_info_t()
            if get_platform_info(&platformInfo) {
                statusText = String(cString: &platformInfo.device_info_str.0) + " " + String(cString: &platformInfo.driver_info_str.0)
            }
            DispatchQueue.main.async {
                self.statusItem?.title = statusText
            }
        }

        NetworkManager.scanNetwork(callback: { networkList in
            DispatchQueue.main.async {
                if networkList.count > 0 {
                    var networkList = networkList
                    for index in 0 ... self.networkItemList.count - 1 {
                        guard let view = self.networkItemList[index].view as? WifiMenuItemView else {
                            continue
                        }
                        if networkList.count > 0 {
                            view.updateNetworkInfo(networkInfo: networkList.removeFirst())
                            view.show()
                        } else {
                            view.hide()
                        }
                    }
                    self.networkItemListSeparator?.isHidden = false
                } else {
                    self.networkItemListSeparator?.isHidden = true
                }
            }
        })
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
