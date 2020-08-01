//
//  JoinPopWindow.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/8.
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

final class JoinPopWindow: NSWindow, NSTextFieldDelegate {
    private let view: NSView
    private let buttonView: NSView
    private let icon: NSImageView
    private let titleLabel: NSTextField
    private let subTitleLabel: NSTextField
    private let ssidLabel: NSTextField
    private let ssidBox: NSTextField
    private let securityLabel: NSTextField
    private let securityPop: NSPopUpButton
    private let usernameLabel: NSTextField
    private let usernameBox: NSTextField
    private let passwdLabel: NSTextView
    private let passwdInputBox: NSTextField
    private let passwdInputBoxCell: NSTextFieldCell
    private let passwdSecureBox: NSSecureTextField
    private let isShowPasswd: NSButton
    private let isSave: NSButton
    private let joinButton: NSButton
    private let cancelButton: NSButton

    convenience init() {
        self.init(
            contentRect: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 247
        ),
        styleMask: .titled,
        backing: .buffered,
        defer: false)
    }

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        view = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 247
        ))
        buttonView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 175
        ))
        icon = NSImageView(frame: NSRect(
            x: 25,
            y: 167,
            width: 64,
            height: 64
        ))
        titleLabel = NSTextField(frame: NSRect(
            x: 105,
            y: 212,
            width: 345,
            height: 16
        ))
        subTitleLabel = NSTextField(frame: NSRect(
            x: 105,
            y: 170,
            width: 310,
            height: 32
        ))
        ssidLabel = NSTextField(frame: NSRect(
            x: 50,
            y: 132,
            width: 120,
            height: 19
        ))
        ssidBox = NSTextField(frame: NSRect(
            x: 173,
            y: 132,
            width: 255,
            height: 21
        ))
        securityLabel = NSTextField(frame: NSRect(
            x: 50,
            y: 103,
            width: 120,
            height: 19
        ))
        securityPop = NSPopUpButton(frame: NSRect(
            x: 171,
            y: 100,
            width: 260,
            height: 26
        ))
        usernameLabel = NSTextField(frame: NSRect(
            x: 50,
            y: 150,
            width: 120,
            height: 19
        ))
        usernameBox = NSTextField(frame: NSRect(
            x: 173,
            y: 151,
            width: 255,
            height: 21
        ))
        passwdLabel = NSTextView(frame: NSRect(
            x: 93,
            y: 121,
            width: 80,
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
            width: 255,
            height: 18
        ))
        isSave = NSButton(frame: NSRect(
            x: 173,
            y: 80,
            width: 255,
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

        super.init(
            contentRect: contentRect,
            styleMask: style,
            backing: backingStoreType,
            defer: flag
        )
        NSApplication.shared.activate(ignoringOtherApps: true)

        icon.image = #imageLiteral(resourceName: "WiFi")
        view.addSubview(icon)

        titleLabel.stringValue = NSLocalizedString("Find and join a Wi-Fi network.")
        titleLabel.drawsBackground = false
        titleLabel.isBordered = false
        titleLabel.isSelectable = false
        titleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        view.addSubview(titleLabel)

        subTitleLabel.stringValue = NSLocalizedString(
            "Enter the name and security type of the network you want to join.",
            comment: ""
        )
        subTitleLabel.drawsBackground = false
        subTitleLabel.isBordered = false
        subTitleLabel.isSelectable = false
        subTitleLabel.font = NSFont.systemFont(ofSize: 11)
        view.addSubview(subTitleLabel)

        ssidLabel.stringValue = NSLocalizedString("Network Name:")
        ssidLabel.drawsBackground = false
        ssidLabel.alignment = .right
        ssidLabel.isBordered = false
        ssidLabel.isSelectable = false
        ssidLabel.font = NSFont.systemFont(ofSize: 13)
        view.addSubview(ssidLabel)

        ssidBox.stringValue = ""
        ssidBox.drawsBackground = true
        ssidBox.isEditable = true
        ssidBox.isSelectable = true
        ssidBox.font = .systemFont(ofSize: 13)
        ssidBox.delegate = self
        view.addSubview(ssidBox)

        securityLabel.stringValue = NSLocalizedString("Security:")
        securityLabel.drawsBackground = false
        securityLabel.alignment = .right
        securityLabel.isBordered = false
        securityLabel.isSelectable = false
        securityLabel.font = .systemFont(ofSize: 13)
        view.addSubview(securityLabel)

        securityPop.addItem(withTitle: NSLocalizedString("None"))
        securityPop.menu?.addItem(.separator())
        //securityPop?.addItem(withTitle: NSLocalizedString("WEP"))
        securityPop.addItem(withTitle: NSLocalizedString("WPA/WPA2 Personal"))
        //securityPop?.addItem(withTitle: NSLocalizedString("WPA2/WPA3 Personal"))
        securityPop.addItem(withTitle: NSLocalizedString("WPA2 Personal"))
        //securityPop?.addItem(withTitle: NSLocalizedString("WPA3 Personal"))
        //securityPop.menu?.addItem(.separator())
        //securityPop?.addItem(withTitle: NSLocalizedString("Dynamic WEP"))
        //securityPop.addItem(withTitle: NSLocalizedString("WPA/WPA2 Enterprise"))
        //securityPop?.addItem(withTitle: NSLocalizedString("WPA2/WPA3 Enterprise"))
        //securityPop.addItem(withTitle: NSLocalizedString("WPA2 Enterprise"))
        //securityPop?.addItem(withTitle: NSLocalizedString("WPA3 Enterprise"))
        securityPop.target = self
        securityPop.action = #selector(security(_:))
        view.addSubview(securityPop)

        usernameLabel.stringValue = NSLocalizedString("Username:")
        usernameLabel.drawsBackground = false
        usernameLabel.alignment = .right
        usernameLabel.isBordered = false
        usernameLabel.isSelectable = false
        usernameLabel.font = .systemFont(ofSize: 13)
        usernameLabel.isHidden = true
        buttonView.addSubview(usernameLabel)

        usernameBox.drawsBackground = true
        usernameBox.isBordered = true
        usernameBox.isEditable = true
        usernameBox.isSelectable = true
        usernameBox.font = .systemFont(ofSize: 13)
        usernameBox.delegate = self
        usernameBox.isHidden = true
        buttonView.addSubview(usernameBox)

        passwdLabel.string = NSLocalizedString("Password:")
        passwdLabel.drawsBackground = false
        passwdLabel.alignment = .right
        passwdLabel.isEditable = false
        passwdLabel.isSelectable = false
        passwdLabel.font = NSFont.systemFont(ofSize: 13)
        passwdLabel.isHidden = true
        buttonView.addSubview(passwdLabel)

        passwdInputBox.cell = passwdInputBoxCell
        passwdInputBoxCell.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        passwdInputBoxCell.isBordered = true
        passwdInputBox.drawsBackground = true
        passwdInputBox.isEditable = true
        passwdInputBox.isSelectable = true
        passwdInputBox.font = NSFont.systemFont(ofSize: 13)
        passwdInputBox.delegate = self
        passwdInputBox.isHidden = true
        buttonView.addSubview(passwdInputBox)

        passwdSecureBox.drawsBackground = true
        passwdSecureBox.isEditable = true
        passwdSecureBox.isSelectable = true
        passwdSecureBox.font = NSFont.systemFont(ofSize: 13)
        passwdSecureBox.delegate = self
        passwdSecureBox.isHidden = true
        buttonView.addSubview(passwdSecureBox)

        isShowPasswd.setButtonType(.switch)
        isShowPasswd.title = NSLocalizedString("Show password")
        isShowPasswd.target = self
        isShowPasswd.action = #selector(showPasswd(_:))
        isShowPasswd.isHidden = true
        buttonView.addSubview(isShowPasswd)

        isSave.setButtonType(.switch)
        isSave.font = .systemFont(ofSize: 13)
        isSave.title = NSLocalizedString("Remember this network")
        isSave.target = self
        isSave.action = #selector(saveWiFi(_:))
        isSave.state = .on
        buttonView.addSubview(isSave)

        joinButton.bezelStyle = NSButton.BezelStyle.rounded
        joinButton.font = .systemFont(ofSize: 13)
        joinButton.title = NSLocalizedString("Join")
        joinButton.target = self
        joinButton.isEnabled = false
        joinButton.keyEquivalent = "\r"
        joinButton.action = #selector(joinWiFi(_:))
        buttonView.addSubview(joinButton)

        cancelButton.bezelStyle = .rounded
        cancelButton.font = .systemFont(ofSize: 13)
        cancelButton.title = NSLocalizedString("Cancel")
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))
        buttonView.addSubview(cancelButton)

        resetInputBoxes()

        view.autoresizingMask = .minYMargin
        buttonView.autoresizingMask = .maxYMargin

        preservesContentDuringLiveResize = true
        contentView?.addSubview(view)
        contentView?.addSubview(buttonView)
        isReleasedWhenClosed = false
        level = .floating
        center()

        // Set WPA Personal as default
        securityPop.selectItem(at: 3)
        security(nil)
        ssidBox.becomeFirstResponder()
    }

    @objc private func security(_ sender: Any?) {
        switch securityPop.title {
        case NSLocalizedString("None"):
            usernameLabel.isHidden = true
            usernameBox.isHidden = true
            passwdLabel.isHidden = true
            passwdInputBox.isHidden = true
            passwdSecureBox.isHidden = true
            isShowPasswd.isHidden = true
            resetInputBoxes()
            controlJoinButton()
            ssidBox.becomeFirstResponder()
            if frame.height == 317 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY + 48,
                    width: 450,
                    height: 269
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
            if frame.height == 345 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY + 76,
                    width: 450,
                    height: 269
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
        case NSLocalizedString("WPA/WPA2 Personal"),
             NSLocalizedString("WPA2/WPA3 Personal"),
             NSLocalizedString("WPA2 Personal"),
             NSLocalizedString("WPA3 Personal"):
            if frame.height == 269 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY - 48,
                    width: 450,
                    height: 317
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
            usernameLabel.isHidden = true
            usernameBox.isHidden = true
            passwdLabel.isHidden = false
            passwdInputBox.isHidden = true
            passwdSecureBox.isHidden = false
            isShowPasswd.isHidden = false
            resetInputBoxes()
            controlJoinButton()
            if frame.height == 345 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY + 28,
                    width: 450,
                    height: 317
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
            passwdSecureBox.becomeFirstResponder()
        case NSLocalizedString("WPA/WPA2 Enterprise"),
             NSLocalizedString("WPA2/WPA3 Enterprise"),
             NSLocalizedString("WPA2 Enterprise"),
             NSLocalizedString("WPA3 Enterprise"):
            if frame.height == 269 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY - 76,
                    width: 450,
                    height: 345
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
            if frame.height == 317 {
                let frameSize = NSRect(
                    x: frame.minX,
                    y: frame.minY - 28,
                    width: 450,
                    height: 345
                )
                setFrame(
                    frameSize,
                    display: false,
                    animate: true
                )
            }
            usernameLabel.isHidden = false
            usernameBox.isHidden = false
            passwdLabel.isHidden = false
            passwdInputBox.isHidden = true
            passwdSecureBox.isHidden = false
            isShowPasswd.isHidden = false
            resetInputBoxes()
            controlJoinButton()
            usernameBox.becomeFirstResponder()
        default:
            let alert = Alert(text: NSLocalizedString("Encryption type unsupported"))
            alert.show()
            controlJoinButton()
            return
        }
    }

    @objc private func showPasswd(_ sender: Any?) {
        passwdSecureBox.stringValue = passwdInputBox.stringValue
        passwdInputBox.isHidden = isShowPasswd.state == .off
        passwdSecureBox.isHidden = isShowPasswd.state == .on

        switch isShowPasswd.state {
        case .off:
            passwdSecureBox.becomeFirstResponder()
            passwdSecureBox.selectText(self)
            passwdSecureBox.currentEditor()?.selectedRange = NSRange(
                location: "\(passwdSecureBox)".count,
                length: 0
            )
        default:
            passwdInputBox.becomeFirstResponder()
            passwdInputBox.selectText(self)
            passwdInputBox.currentEditor()?.selectedRange = NSRange(
                location: "\(passwdInputBox)".count,
                length: 0
            )
        }
    }

    @objc private func saveWiFi(_ sender: Any?) {

    }

    @objc private func joinWiFi(_ sender: Any?) {
        let networkInfo = NetworkInfo(ssid: ssidBox.stringValue)
        networkInfo.auth.password = passwdInputBox.stringValue

        switch securityPop.indexOfSelectedItem {
        case 0:
            networkInfo.auth.security = ITL80211_SECURITY_NONE

        case 2:
            networkInfo.auth.security = ITL80211_SECURITY_WPA_PERSONAL_MIXED
        case 3:
            networkInfo.auth.security = ITL80211_SECURITY_WPA2_PERSONAL

        case 5:
            networkInfo.auth.security = ITL80211_SECURITY_WPA_ENTERPRISE_MIXED
        case 6:
            networkInfo.auth.security = ITL80211_SECURITY_WPA2_ENTERPRISE

        default:
            networkInfo.auth.security = ITL80211_SECURITY_UNKNOWN
        }

        NetworkManager.connect(networkInfo: networkInfo, saveNetwork: isSave.state == .on)
        close()
    }

    @objc private func cancel(_ sender: Any?) {
        close()
    }

    private func resetInputBoxes() {
        passwdInputBox.stringValue = ""
        passwdSecureBox.stringValue = ""
        usernameBox.stringValue = ""
    }

    private func controlJoinButton() {
        // SSID needs to be filled in and shorter than 32 characters
        guard !ssidBox.stringValue.isEmpty, ssidBox.stringValue.count <= 32 else {
            joinButton.isEnabled = false
            return
        }

        // no password used, both password inputs are hidden
        if passwdInputBox.isHidden, passwdSecureBox.isHidden {
            joinButton.isEnabled = true
            return
        }

        // password is too short, less than 8 characters
        guard (!passwdInputBox.isHidden || !passwdSecureBox.isHidden),
            passwdSecureBox.stringValue.count >= 8,
            passwdInputBox.stringValue.count >= 8  else {
            joinButton.isEnabled = false
            return
        }

        // user name input shown but not filled in
        if !usernameBox.isHidden, usernameBox.stringValue.isEmpty {
            joinButton.isEnabled = false
            return
        }

        // everything is OK
        joinButton.isEnabled = true
    }

    func controlTextDidChange(_ obj: Notification) {
        // if clear password box is visible, copy password to secure box
        if !passwdInputBox.isHidden {
            passwdSecureBox.stringValue = passwdInputBox.stringValue
        }

        // if clear password box is not visible, copy password from secure box to password box
        if passwdInputBox.isHidden {
            passwdInputBox.stringValue = passwdSecureBox.stringValue
        }

        // trim secure box to 64 characters
        if passwdSecureBox.stringValue.count > 64 {
            passwdSecureBox.stringValue = String(passwdSecureBox.stringValue[..<passwdSecureBox.stringValue.index(
                passwdSecureBox.stringValue.startIndex,
                offsetBy: 64
            )])
        }

        // trim password box to 64 characters
        if passwdInputBox.stringValue.count > 64 {
            passwdInputBox.stringValue = String(passwdInputBox.stringValue[..<passwdInputBox.stringValue.index(
                passwdInputBox.stringValue.startIndex,
                offsetBy: 64
            )])
        }

        controlJoinButton()
    }

    func show() {
        makeKeyAndOrderFront(self)
    }
}
