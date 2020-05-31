//
//  WiFiPopover.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/4.
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

class WiFiPopoverSubview: NSView,NSWindowDelegate, NSTextFieldDelegate{
    var popWindow: NSWindow?
    var view: NSView?
    var icon: NSImageView?
    var title: NSTextField?
    var passwdLabel: NSTextView?
    var passwdInputBox: NSTextField?
    var passwdInputBoxCell: NSTextFieldCell?
    var passwdInputBox1: NSSecureTextField?
    var isShowPasswd: NSButton?
    var isSave:NSButton?
    var joinButton: NSButton?
    var cancelButton: NSButton?

    var networkInfo: NetworkInfo?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    func initViews(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo

        view = NSView(frame: NSRect(x: 0, y: 0, width: 450, height: 247))
        icon = NSImageView(frame: NSRect(x: 25, y: 165, width: 64, height: 64))
        title = NSTextField(frame: NSRect(x: 105, y: 210, width: 345, height: 16))
        passwdLabel = NSTextView(frame: NSRect(x: 128, y: 124, width: 100, height: 19))
        passwdInputBox = NSTextField(frame: NSRect(x: 173, y: 124, width: 255, height: 21))
        passwdInputBoxCell = NSTextFieldCell.init()
        passwdInputBox1 = NSSecureTextField(frame: NSRect(x: 173, y: 124, width: 255, height: 21))
        isShowPasswd = NSButton(frame: NSRect(x: 173, y: 100, width: 100, height: 18))
        isSave = NSButton(frame: NSRect(x: 173, y: 80, width: 100, height: 18))
        joinButton = NSButton(frame: NSRect(x: 353, y: 18, width: 85, height: 22))
        cancelButton = NSButton(frame: NSRect(x: 269, y: 18, width: 85, height: 22))
        
        icon?.image = NSImage.init(named: "WiFi")
        view?.addSubview(icon!)
        
        title?.stringValue = NSLocalizedString("Wi-Fi Network \"", comment: "")/*"Wi-Fi网络 "*/ + self.networkInfo!.ssid + NSLocalizedString("\" Requires Password", comment: "")/*" 需要密码。"*/
        title?.drawsBackground = false
        title?.isBordered = false
        title?.isSelectable = false
        title?.font = NSFont.boldSystemFont(ofSize: 13)//systemFont(ofSize: 13).
        view?.addSubview(title!)
        
        passwdLabel?.string = NSLocalizedString("Password: ", comment: "")/*"密码："*/
        passwdLabel?.drawsBackground = false
        passwdLabel?.isEditable = false
        passwdLabel?.isSelectable = false
        passwdLabel?.font = NSFont.systemFont(ofSize: 13)
        view?.addSubview(passwdLabel!)
        
        passwdInputBox?.cell = passwdInputBoxCell
        passwdInputBoxCell?.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        passwdInputBoxCell?.isBordered = true
        passwdInputBox?.stringValue = ""
        //passwdInputBox?.drawsBackground = true
        passwdInputBox?.isEditable = true
        passwdInputBox?.isSelectable = true
        passwdInputBox?.font = NSFont.systemFont(ofSize: 13)
        passwdInputBox?.delegate = self
        passwdInputBox?.isHidden = true
        //passwdInputBoxCell?.drawsBackground = true
        view?.addSubview(passwdInputBox!)
        
        passwdInputBox1?.stringValue = ""
        passwdInputBox1?.drawsBackground = true
        passwdInputBox1?.isEditable = true
        passwdInputBox1?.isSelectable = true
        passwdInputBox1?.font = NSFont.systemFont(ofSize: 13)
        passwdInputBox1?.delegate = self
        passwdInputBox1?.isHidden = false
        view?.addSubview(passwdInputBox1!)
        
        isShowPasswd?.setButtonType(.switch)
        isShowPasswd?.title = NSLocalizedString("Show Password", comment: "")/*"显示密码"*/
        isShowPasswd?.target = self
        isShowPasswd?.action = #selector(showPasswd(_:))
        view?.addSubview(isShowPasswd!)
        
        isSave?.setButtonType(.switch)
        isSave?.title = NSLocalizedString("Remember This Network", comment: "")/*"记住该网络"*/
        isSave?.target = self
        isSave?.action = #selector(saveWiFi(_:))
        view?.addSubview(isSave!)
        
        joinButton?.bezelStyle = NSButton.BezelStyle.rounded
        joinButton?.title = NSLocalizedString("Join", comment: "")/*"加入"*/
        joinButton?.target = self
        joinButton?.isEnabled = false
        joinButton?.action = #selector(connect(_:))
        view?.addSubview(joinButton!)
        
        cancelButton?.bezelStyle = .rounded
        cancelButton?.title = NSLocalizedString("Cancel", comment: "")/*"取消"*/
        cancelButton?.target = self
        cancelButton?.action = #selector(cancel(_:))
        view?.addSubview(cancelButton!)
        
        if let _ = view { addSubview(view!) }
    }
    
    @objc func showPasswd(_ sender: Any?) {
        if isShowPasswd?.state.rawValue == 0 {
            passwdInputBox1?.stringValue = (passwdInputBox?.stringValue)!
            passwdInputBox?.isHidden = true
            passwdInputBox1?.isHidden = false
            passwdInputBox1?.becomeFirstResponder()
            passwdInputBox1?.selectText(self)
            passwdInputBox1?.currentEditor()?.selectedRange = NSRange(location: "\((passwdInputBox1)!)".count, length: 0)
        }
        if isShowPasswd?.state.rawValue == 1 {
            passwdInputBox?.stringValue = (passwdInputBox1?.stringValue)!
            passwdInputBox?.isHidden = false
            passwdInputBox1?.isHidden = true
            passwdInputBox?.becomeFirstResponder()
            passwdInputBox?.selectText(self)
            passwdInputBox?.currentEditor()?.selectedRange = NSRange(location: "\((passwdInputBox)!)".count, length: 0)
        }
    }
    
    @objc func saveWiFi(_ sender: Any?) {

    }
    
    @objc func cancel(_ sender: Any?) {
        popWindow?.close()
    }

    @objc func connect(_ sender: Any?) {
        networkInfo?.setPassword(password: passwdInputBox!.stringValue);
        DispatchQueue.global(qos: .background).async {
            let result = self.networkInfo?.connect()
            DispatchQueue.main.async {
                if result! {
                    StatusBarIcon.connected()
                } else {
                    StatusBarIcon.disconnected()
                }
            }
        }
        popWindow?.close()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        if passwdInputBox?.isHidden == false {
            passwdInputBox1?.stringValue = (passwdInputBox?.stringValue)!
        } else {
            passwdInputBox?.stringValue = (passwdInputBox1?.stringValue)!
        }
        if (passwdInputBox1?.stringValue.count)! < 8 && (passwdInputBox?.stringValue.count)! < 8 {
            joinButton?.isEnabled = false
        } else {
            joinButton?.isEnabled = true
        }
        if (passwdInputBox1?.stringValue.count)! > 64 {
            let index = passwdInputBox1?.stringValue.index((passwdInputBox1?.stringValue.startIndex)!, offsetBy: 64)
            passwdInputBox1?.stringValue = String((passwdInputBox1?.stringValue[..<index!])!)
        }
        if (passwdInputBox?.stringValue.count)! > 64 {
            let index = passwdInputBox?.stringValue.index((passwdInputBox?.stringValue.startIndex)!, offsetBy: 64)
            passwdInputBox?.stringValue = String((passwdInputBox?.stringValue[..<index!])!)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
