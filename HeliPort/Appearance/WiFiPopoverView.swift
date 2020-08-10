//
//  WiFiPopover.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/4.
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

class WiFiPopoverSubview: NSView, NSWindowDelegate, NSTextFieldDelegate {
    var popWindow: NSWindow
    var view: NSView
    var icon: NSImageView
    var title: NSTextField
    var passwdLabel: NSTextView
    var passwdInputBox: NSTextField
    var passwdInputBoxCell: NSTextFieldCell
    var passwdSecureBox: NSSecureTextField
    var isShowPasswd: NSButton
    var isSave: NSButton
    var joinButton: NSButton
    var cancelButton: NSButton

    var networkInfo: NetworkInfo
    var getAuthInfoCallback: ((_ auth: NetworkAuth, _ savePassword: Bool) -> Void)

    init(
        popWindow: NSWindow,
        networkInfo: NetworkInfo,
        getAuthInfoCallback: @escaping (_ auth: NetworkAuth, _ savePassword: Bool) -> Void
    ) {
        self.popWindow = popWindow
        self.networkInfo = networkInfo
        self.getAuthInfoCallback = getAuthInfoCallback

        view = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 247
        ))
        icon = NSImageView(frame: NSRect(
            x: 25,
            y: 165,
            width: 64,
            height: 64
        ))
        title = NSTextField(frame: NSRect(
            x: 105,
            y: 160,
            width: 300,
            height: 64
        ))
        passwdLabel = NSTextView(frame: NSRect(
            x: 73,
            y: 124,
            width: 100,
            height: 19
        ))
        passwdInputBox = NSTextField(frame: NSRect(
            x: 173,
            y: 124,
            width: 255,
            height: 21
        ))
        passwdInputBoxCell = NSTextFieldCell.init()
        passwdSecureBox = NSSecureTextField(frame: NSRect(
            x: 173,
            y: 124,
            width: 255,
            height: 21
        ))
        isShowPasswd = NSButton(frame: NSRect(
            x: 173,
            y: 100,
            width: 170,
            height: 18
        ))
        isSave = NSButton(frame: NSRect(
            x: 173,
            y: 80,
            width: 170,
            height: 18
        ))
        joinButton = NSButton(frame: NSRect(
            x: 353,
            y: 18,
            width: 85,
            height: 22
        ))
        cancelButton = NSButton(frame: NSRect(
            x: 269,
            y: 18,
            width: 85,
            height: 22
        ))

        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 247
        ))

        NSApplication.shared.activate(ignoringOtherApps: true)
        icon.image = #imageLiteral(resourceName: "WiFi")
        view.addSubview(icon)

        title.stringValue =
            NSLocalizedString("Wi-Fi Network \"") +
            self.networkInfo.ssid +
            NSLocalizedString("\" Requires Password")
        title.drawsBackground = false
        title.isBordered = false
        title.isSelectable = false
        title.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(title)

        passwdLabel.string = NSLocalizedString("Password:")
        passwdLabel.alignment = .right
        passwdLabel.drawsBackground = false
        passwdLabel.isEditable = false
        passwdLabel.isSelectable = false
        passwdLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(passwdLabel)

        passwdInputBox.cell = passwdInputBoxCell
        passwdInputBoxCell.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        passwdInputBoxCell.isBordered = true
        passwdInputBox.stringValue = ""
        passwdInputBox.drawsBackground = true
        passwdInputBox.isEditable = true
        passwdInputBox.isSelectable = true
        passwdInputBox.font = NSFont.systemFont(ofSize: 13)
        passwdInputBox.delegate = self
        passwdInputBox.isHidden = true
        //passwdInputBoxCell.drawsBackground = true
        view.addSubview(passwdInputBox)

        passwdSecureBox.stringValue = ""
        passwdSecureBox.drawsBackground = true
        passwdSecureBox.isEditable = true
        passwdSecureBox.isSelectable = true
        passwdSecureBox.font = NSFont.systemFont(ofSize: 13)
        passwdSecureBox.delegate = self
        passwdSecureBox.isHidden = false
        view.addSubview(passwdSecureBox)

        isShowPasswd.setButtonType(.switch)
        isShowPasswd.font = .systemFont(ofSize: 13)
        isShowPasswd.title = NSLocalizedString("Show password")
        isShowPasswd.target = self
        isShowPasswd.action = #selector(showPasswd(_:))
        view.addSubview(isShowPasswd)

        isSave.setButtonType(.switch)
        isSave.font = .systemFont(ofSize: 13)
        isSave.title = NSLocalizedString("Remember this network")
        isSave.state = .on
        view.addSubview(isSave)

        joinButton.bezelStyle = NSButton.BezelStyle.rounded
        joinButton.font = .systemFont(ofSize: 13)
        joinButton.title = NSLocalizedString("Join")
        joinButton.target = self
        joinButton.isEnabled = false
        joinButton.keyEquivalent = "\r"
        joinButton.action = #selector(connect(_:))
        view.addSubview(joinButton)

        cancelButton.bezelStyle = .rounded
        cancelButton.font = .systemFont(ofSize: 13)
        cancelButton.title = NSLocalizedString("Cancel")
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))
        view.addSubview(cancelButton)

        addSubview(view)
    }

    @objc func showPasswd(_ sender: Any?) {
        if isShowPasswd.state == .off {
            passwdSecureBox.stringValue = (passwdInputBox.stringValue)
            passwdInputBox.isHidden = true
            passwdSecureBox.isHidden = false
            passwdSecureBox.becomeFirstResponder()
            passwdSecureBox.selectText(self)
            passwdSecureBox.currentEditor()?.selectedRange = NSRange(
                location: "\((passwdSecureBox))".count,
                length: 0
            )
        } else {
            passwdInputBox.stringValue = (passwdSecureBox.stringValue)
            passwdInputBox.isHidden = false
            passwdSecureBox.isHidden = true
            passwdInputBox.becomeFirstResponder()
            passwdInputBox.selectText(self)
            passwdInputBox.currentEditor()?.selectedRange = NSRange(
                location: "\((passwdInputBox))".count,
                length: 0
            )
        }
    }

    @objc func cancel(_ sender: Any?) {
        popWindow.close()
    }

    @objc func connect(_ sender: Any?) {
        networkInfo.auth.password = passwdInputBox.stringValue
        getAuthInfoCallback(networkInfo.auth, isSave.state == .on)
        popWindow.close()
    }

    func controlTextDidChange(_ obj: Notification) {
        if passwdInputBox.isHidden == false {
            passwdSecureBox.stringValue = (passwdInputBox.stringValue)
        } else {
            passwdInputBox.stringValue = (passwdSecureBox.stringValue)
        }
        if (passwdSecureBox.stringValue.count) < 8 && (passwdInputBox.stringValue.count) < 8 {
            joinButton.isEnabled = false
        } else {
            joinButton.isEnabled = true
        }
        if (passwdSecureBox.stringValue.count) > 64 {
            let index = passwdSecureBox.stringValue.index(
                (passwdSecureBox.stringValue.startIndex),
                offsetBy: 64
            )
            passwdSecureBox.stringValue = String((passwdSecureBox.stringValue[..<index]))
        }
        if (passwdInputBox.stringValue.count) > 64 {
            let index = passwdInputBox.stringValue.index((
                passwdInputBox.stringValue.startIndex),
                offsetBy: 64
            )
            passwdInputBox.stringValue = String((passwdInputBox.stringValue[..<index]))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
