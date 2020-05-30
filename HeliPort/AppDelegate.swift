//
//  AppDelegate.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/3/20.
//  Copyright © 2020 lhy. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

var statusBar:NSStatusItem!
let wifiPop:NSAlert = NSAlert()

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    var password:String = ""
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application

        if (!connect_driver()) {
            //exit(0);
        }
        
        statusBar = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBar.button?.image = NSImage.init(named: "AirPortInMenu0")
        statusBar.button?.image?.isTemplate = true
        statusBar.menu = StatusMenu.init(title: "")
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
        // TODO: disconnect_driver();
    }
    
}
