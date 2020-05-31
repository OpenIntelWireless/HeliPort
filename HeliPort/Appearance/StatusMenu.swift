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

class StatusMenu: NSMenu, NSMenuDelegate {
    let networkListUpdatePeriod: Double = 5

    var headerLength: Int = 0
    var timer: Timer?
    var showAllOptions: Bool = false
    var networkCount:Int = 0

    var statusItem: NSMenuItem?
    
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

        addItem(withTitle: NSLocalizedString("No Network Avaliable", comment: ""), action: nil, keyEquivalent: "").isEnabled = false
        networkCount = 1

        addItem(NSMenuItem.separator())
        addItem(withTitle: NSLocalizedString("Join Other Network...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Create Network...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Open Network Preferences...", comment: ""), action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
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

        if (showAllOptions) {
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
        items[items.count - 1].isHidden = true
    }
    
    func buildOptionMenu() {
        for idx in 0...5 {
            items[idx].isHidden = false
        }
        items[items.count - 1].isHidden = false
    }
    
    @objc func clickMenuItem(_ sender:NSMenuItem){
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
        case NSLocalizedString("Open Network Preferences...", comment: ""):
            NSWorkspace.shared.openFile("/System/Library/PreferencePanes/Network.prefPane")
        case NSLocalizedString("Quit HeliPort", comment: ""):
            exit(0)
        default:
            print("Default")
            //let url = URL(string: "x-apple.systempreferences:com.apple.preference.network")!
            //NSWorkspace.shared.open(url)
        }
    }

    func addNetworkItem(wifi: NetworkInfo) {
        insertItem(withTitle: "Foo",
                   action: #selector(clickMenuItem(_:)),
                   keyEquivalent: "",
                   at: headerLength).view =
            WifiMenuItemView.createItem(frame: NSRect(x: 0, y: 0, width: 285, height: 20), wifi: wifi)
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
        DispatchQueue.global(qos: .background).async {
            let networkList = NetworkInfo.scanNetwork().reversed()
            DispatchQueue.main.async {
                if (self.networkCount > 0) {
                    for _ in 1...self.networkCount {
                        self.removeItem(at: self.headerLength)
                    }
                }
                if networkList.count > 0 {
                    for networkInfo in networkList {
                        self.addNetworkItem(wifi: networkInfo)
                    }
                    self.networkCount = networkList.count
                } else {
                    self.insertItem(withTitle: NSLocalizedString("No Network Avaliable", comment: ""), action: nil, keyEquivalent: "", at: self.headerLength).isEnabled = false
                    self.networkCount = 1
                }
            }
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
