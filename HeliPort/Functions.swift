//
//  Functions.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/6.
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


class Functions {
    class func WiFiPop() {
        var popWindow: NSWindow?
        var view: NSView?
        var icon: NSImageView?
        var title: NSTextField?
        
        popWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 247), styleMask: NSWindow.StyleMask.titled, backing: NSWindow.BackingStoreType.buffered, defer: false)
        view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 247))
        icon = NSImageView(frame: NSRect(x: 25, y: 165, width: 64, height: 64))
        title = NSTextField(frame: NSRect(x: 105, y: 210, width: 345, height: 16))
        
        icon?.image = NSImage.init(named: "WiFi")
        view?.addSubview(icon!)
        
        title?.stringValue = "Wi-Fi网络“Foo“需要WPA2密码。"
        title?.drawsBackground = false
        title?.isBordered = false
        title?.isSelectable = false
        title?.font = NSFont.boldSystemFont(ofSize: 13)//systemFont(ofSize: 13).
        view?.addSubview(title!)
        
        view?.addSubview(WiFiPopoverSubview(frame: NSRect(x: 128, y: 18, width: 322, height: 125)))
        
        popWindow?.center()
        popWindow?.isOpaque = false
        popWindow?.level = NSWindow.Level.popUpMenu
        popWindow?.contentView = view
        popWindow?.makeKeyAndOrderFront(self)
        /*
        WiFiPopup.icon = NSImage.init(named: "WiFi")
        WiFiPopup.messageText = "Wi-Fi网络“Bar”需要WPA2密码。"
        WiFiPopup.alertStyle = NSAlert.Style.informational
        WiFiPopup.addButton(withTitle: "加入")
        WiFiPopup.addButton(withTitle: "取消")
        WiFiPopup.buttons[0].isEnabled = false
        WiFiPopup.showsHelp = true
        WiFiPopup.accessoryView = WiFiPopoverSubview(frame: NSRect(x: 0, y: 0, width: 300, height: 80))//WiFiSubView
        WiFiPopup.window.initialFirstResponder = WiFiPopoverSubview.passwdInputBox1 //WiFiPasswdField
        //WiFiPopup.runModal()
        */
    }
}
