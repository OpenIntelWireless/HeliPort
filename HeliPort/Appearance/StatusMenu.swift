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
    
    override init(title: String) {
        super.init(title: title)
        minimumWidth = CGFloat(285.0)
        delegate = self
        //autoenablesItems = false
        setupMenuHeaderAndFooter()
        updateNetworkList()
    }

    func setupMenuHeaderAndFooter() {
        addItem(withTitle: "接口名称： en1", action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: "地址： aa:bb:cc:dd:ee:ff", action: nil, keyEquivalent: "").isHidden = true
        addItem(withTitle: "启用Wi-Fi记录", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: "创建诊断报告...", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: "打开无线诊断...", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())
        var platformInfo = platform_info_t()
        get_platform_info(&platformInfo)
        addItem(withTitle: String(cString: &platformInfo.device_info_str.0) + " " + String(cString: &platformInfo.driver_info_str.0), action: nil, keyEquivalent: "").isEnabled = false
        addItem(withTitle: "关闭Wi-Fi", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(NSMenuItem.separator())
        headerLength = items.count
        addItem(NSMenuItem.separator())
        addItem(withTitle: "加入其他网络...", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: "创建网络...", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: "打开网络偏好设置...", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
        addItem(withTitle: "退出", action: #selector(clickMenuItem(_:)), keyEquivalent: "").target = self
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
        for i in 0...5 {
            items[i].isHidden = true
        }
        items[items.count - 1].isHidden = true
    }
    
    func buildOptionMenu() {
        for i in 0...5 {
            items[i].isHidden = false
        }
        items[items.count - 1].isHidden = false
    }
    
    @objc func clickMenuItem(_ sender:NSMenuItem){
        print(sender.title)
        switch sender.title {
        case "开启Wi-Fi":
            //items[6].title = "Wi-Fi: 开启"
            //items[7].title = "关闭Wi-Fi"
            StatusBarIcon.on()
        case "关闭Wi-Fi":
            //items[6].title = "Wi-Fi: 关闭"
            //items[7].title = "开启Wi-Fi"
            //timer?.invalidate()
            //timer = nil
            //StatusBarIcon.off()
            let alert = NSAlert()
            alert.messageText = "功能尚未实现"
            alert.alertStyle = NSAlert.Style.critical
            alert.runModal()
        case "加入其他网络...":
            let joinPop = JoinPopWindow.init(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247), styleMask: .titled, backing: .buffered, defer: false)
            joinPop.makeKeyAndOrderFront(self)
        case "打开网络偏好设置...":
            NSWorkspace.shared.openFile("/System/Library/PreferencePanes/Network.prefPane")
        case "退出":
            exit(0)
        default:
            print("Default")
            //let url = URL(string: "x-apple.systempreferences:com.apple.preference.network")!
            //NSWorkspace.shared.open(url)
        }
    }

    func addNetworkItem(wifi: NetworkInfo) {
        insertItem(withTitle: "Foo", action: #selector(clickMenuItem(_:)), keyEquivalent: "", at: headerLength).view = wifiMenuItemView.createItem(frame: NSRect(x: 0, y: 0, width: 285, height: 20), wifi: wifi)
    }

    @objc func updateNetworkList() {
        DispatchQueue.main.async {
            let networkList = NetworkInfo.scanNetwork().reversed()
            if (self.networkCount > 0) {
                for _ in 1...self.networkCount {
                    self.removeItem(at: self.headerLength)
                }
            }
            for networkInfo in networkList {
                self.addNetworkItem(wifi: networkInfo)
            }
            self.networkCount = networkList.count
        }
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
