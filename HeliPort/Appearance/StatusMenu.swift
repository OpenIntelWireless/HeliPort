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
        addItem(withTitle: NSLocalizedString("Interface Name: en1", comment: "")/*接口名称：en1*/, action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: NSLocalizedString("Address: AA:BB:CC:DD:EE:FF", comment: "")/*"地址： aa:bb:cc:dd:ee:ff"*/, action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: NSLocalizedString("Enable Wi-Fi Logging", comment: "")/*"启用Wi-Fi记录"*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Create Diagnostics Report...", comment: "")/*"创建诊断报告..."*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Open Wireless Diagnostics...", comment: "")/*"打开无线诊断..."*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())

        statusItem = addItem(withTitle: NSLocalizedString("Unavaliable", comment: "")/*"不可用"*/, action: nil, keyEquivalent: "")
        statusItem?.isEnabled = false
        addItem(withTitle: NSLocalizedString("Turn Wi-Fi Off", comment: "")/*"关闭Wi-Fi"*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())

        headerLength = items.count

        addItem(withTitle: NSLocalizedString("No Network Avaliable", comment: "")/*"无可用网络"*/, action: nil, keyEquivalent: "").isEnabled = false
        networkCount = 1

        addItem(NSMenuItem.separator())
        addItem(withTitle: NSLocalizedString("Join Other Network...", comment: "")/*"加入其他网络..."*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Create Network...", comment: "")/*"创建网络..."*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Open Network Preferences...", comment: "")/*"打开网络偏好设置..."*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: NSLocalizedString("Quit HeliPort", comment: "")/*"退出 HeliPort"*/, action: #selector(clickMenuItem(_:)), keyEquivalent: "Q").target = self
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
        case NSLocalizedString("Turn Wi-Fi On", comment: "")/*"开启Wi-Fi"*/:
            //items[6].title = NSLocalizedString("Wi-Fi: On", comment: "")/*"Wi-Fi: 开启"*/
            //items[7].title = NSLocalizedString("Turn Wi-Fi Off", comment: "")/*"关闭Wi-Fi"*/
            StatusBarIcon.on()
        case NSLocalizedString("Turn Wi-Fi Off", comment: "")/*"关闭Wi-Fi"*/:
            //items[6].title = NSLocalizedString("Wi-Fi: Off", comment: "")/*"Wi-Fi: 关闭"*/
            //items[7].title = NSLocalizedString("Turn Wi-Fi On", comment: "")/*"开启Wi-Fi"*/
            //timer?.invalidate()
            //timer = nil
            //StatusBarIcon.off()
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("FUNCTION NOT IMPLEMENTED", comment: "")/*"功能尚未实现"*/
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        case NSLocalizedString("Join Other Network...", comment: "")/*"加入其他网络..."*/:
            let joinPop = JoinPopWindow.init(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247), styleMask: .titled, backing: .buffered, defer: false)
            joinPop.makeKeyAndOrderFront(self)
        case NSLocalizedString("Open Network Preferences...", comment: "")/*"打开网络偏好设置..."*/:
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
            var statusText = NSLocalizedString("No Status Information Avaliable", comment: "")/*"状态信息不可用"*/
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
                    self.insertItem(withTitle: NSLocalizedString("No Network Avaliable", comment: "")/*"无可用网络"*/, action: nil, keyEquivalent: "", at: self.headerLength).isEnabled = false
                    self.networkCount = 1
                }
            }
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
