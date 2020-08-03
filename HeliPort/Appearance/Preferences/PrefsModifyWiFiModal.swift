//
//  PrefsModifyWiFiModal.swift
//  HeliPort
//
//  Created by Erik Bautista on 8/3/20.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Cocoa

class PrefsModifyWiFiModal: NSWindow, NSTextFieldDelegate {

    private var networkInfo: NetworkInfo

    private let view: NSView

    private let icon: NSImageView = {
        let image = NSImageView(frame: NSRect.zero)
        image.image = #imageLiteral(resourceName: "WiFi")
        return image
    }()

    private let titleLabel: NSTextField = {
        let label = NSTextField(frame: NSRect.zero)
        label.drawsBackground = false
        label.isBordered = false
        label.isSelectable = false
        label.font = NSFont.boldSystemFont(ofSize: 13)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let subTitleLabel: NSTextField = {
       let label = NSTextField(frame: NSRect.zero)
        label.stringValue = .subTitle
        label.drawsBackground = false
        label.isBordered = false
        label.isSelectable = false
        label.font = NSFont.systemFont(ofSize: 11)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let securityLabel: NSTextField = {
        let label = NSTextField(frame: NSRect.zero)
        label.stringValue = .security
        label.drawsBackground = false
        label.alignment = .right
        label.isBordered = false
        label.isSelectable = false
        label.font = .systemFont(ofSize: 13)
        return label
    }()

    private let securityPop: NSPopUpButton = {
        let pop = NSPopUpButton(frame: NSRect.zero)
        pop.addItem(withTitle: .none)
        pop.menu?.addItem(.separator())
        //pop?.addItem(withTitle: NSLocalizedString("WEP", comment: ""))
        pop.addItem(withTitle: .wpa1_2_Personal)
        //pop?.addItem(withTitle: NSLocalizedString("WPA2/WPA3 Personal", comment: ""))
        pop.addItem(withTitle: .wpa2Personal)
        //pop?.addItem(withTitle: NSLocalizedString("WPA3 Personal", comment: ""))
        pop.menu?.addItem(.separator())
        //pop?.addItem(withTitle: NSLocalizedString("Dynamic WEP", comment: ""))
        pop.addItem(withTitle: .wpa1_2_Enterprise)
        //pop?.addItem(withTitle: NSLocalizedString("WPA2/WPA3 Enterprise", comment: ""))
        pop.addItem(withTitle: .wpa2Enterprise)
        //pop?.addItem(withTitle: NSLocalizedString("WPA3 Enterprise", comment: ""))
        pop.action = #selector(security(_:))
        pop.selectItem(withTitle: .wpa2Personal)
        pop.isEnabled = false
        return pop
    }()

    private let usernameLabel: NSTextField = {
        let label = NSTextField(frame: NSRect.zero)
        label.stringValue = .username
        label.drawsBackground = false
        label.alignment = .right
        label.isBordered = false
        label.isSelectable = false
        label.font = .systemFont(ofSize: 13)
        label.isHidden = true
        return label
    }()

    private let usernameBox: NSTextField = {
        let box = NSTextField(frame: NSRect.zero)
        box.drawsBackground = true
        box.isEditable = true
        box.isSelectable = true
        box.font = .systemFont(ofSize: 13)
        box.isHidden = true
        box.usesSingleLineMode = true
        return box
    }()

    private let passwdLabel: NSTextField = {
        let label = NSTextField(frame: NSRect.zero)
        label.stringValue = .password
        label.drawsBackground = false
        label.alignment = .right
        label.isBordered = false
        label.isSelectable = false
        label.font = .systemFont(ofSize: 13)
        label.isHidden = false
        return label
    }()

    private let passwdInputBox: NSTextField = {
        let box = NSTextField(frame: NSRect.zero)
        box.drawsBackground = false
        box.isSelectable = false
        box.isEditable = false
        box.font = NSFont.systemFont(ofSize: 13)
        box.isHidden = true
        box.usesSingleLineMode = true
        (box.cell as? NSTextFieldCell)?.allowedInputSourceLocales = [NSAllRomanInputSourcesLocaleIdentifier]
        return box
    }()

    private let passwdSecureBox: NSSecureTextField = {
        let box = NSSecureTextField(frame: NSRect.zero)
        box.drawsBackground = false
        box.isEditable = false
        box.isSelectable = false
        box.font = NSFont.systemFont(ofSize: 13)
        box.isHidden = false
        box.usesSingleLineMode = true
        return box
    }()

    private let isShowPasswd: NSButton = {
        let button = NSButton(frame: NSRect.zero)
        button.setButtonType(.switch)
        button.title = .showPassword
        button.action = #selector(showPasswd(_:))
        button.isHidden = false
        return button
    }()

    private let editButton: NSButton = {
        let button = NSButton(frame: NSRect.zero)
        button.bezelStyle = NSButton.BezelStyle.rounded
        button.font = .systemFont(ofSize: 13)
        button.title = .edit
        button.isEnabled = false
        button.keyEquivalent = "\r"
        button.isEnabled = false
//        button.action = #selector(editWiFi(_:))
        return button
    }()

    private let cancelButton: NSButton = {
        let button = NSButton(frame: NSRect.zero)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 13)
        button.title = .exit
        button.action = #selector(cancel(_:))
        return button
    }()

    private var usernameHeightCon: NSLayoutConstraint!
    private var passwrdHeightCon: NSLayoutConstraint!
    private var showPassToggleHeightCon: NSLayoutConstraint!
    private var hideMarginCon: [NSLayoutConstraint] = [NSLayoutConstraint]()

    convenience init(networkInfo: NetworkInfo) {
        self.init(
            contentRect: NSRect(
            x: 0,
            y: 0,
            width: 450,
            height: 247
        ),
        styleMask: .titled,
        backing: .buffered,
        defer: false,
        network: networkInfo)
    }

    init(contentRect: NSRect,
         styleMask style: NSWindow.StyleMask,
         backing backingStoreType: NSWindow.BackingStoreType,
         defer flag: Bool, network: NetworkInfo) {

        self.networkInfo = network
        view = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: contentRect.width,
            height: contentRect.height
        ))

        super.init(contentRect: contentRect,
                   styleMask: style,
                   backing: backingStoreType,
                   defer: flag)

        NSApplication.shared.activate(ignoringOtherApps: true)

        view.addSubview(icon)
        titleLabel.stringValue = String(format: .title, networkInfo.ssid)
        view.addSubview(titleLabel)
        view.addSubview(subTitleLabel)

        view.addSubview(securityLabel)

        securityPop.target = self
        view.addSubview(securityPop)
        view.addSubview(usernameLabel)

        usernameBox.delegate = self
        view.addSubview(usernameBox)

        view.addSubview(passwdLabel)

        passwdInputBox.delegate = self
        view.addSubview(passwdInputBox)

        passwdSecureBox.delegate = self
        view.addSubview(passwdSecureBox)

        isShowPasswd.target = self
        view.addSubview(isShowPasswd)

        editButton.target = self
        view.addSubview(editButton)

        cancelButton.target = self
        view.addSubview(cancelButton)

        resetInputBoxes()

        contentView = view
        isReleasedWhenClosed = false
        level = .floating
        center()

        setupConstraints()

        usernameBox.stringValue = networkInfo.auth.username
        securityPop.selectItem(withTitle: NSLocalizedString(networkInfo.auth.security.description))
        passwdInputBox.stringValue = networkInfo.auth.password
        passwdSecureBox.stringValue = networkInfo.auth.password
    }

    private func setupConstraints() {
        view.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        let constraints = [
            // Icon
            icon.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            icon.topAnchor.constraint(equalTo: view.topAnchor, constant: 15),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),

            // Title
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            titleLabel.heightAnchor.constraint(equalToConstant: 16),

            // Subtitle
            subTitleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 20),
            subTitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            // Security label
            securityLabel.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
            securityLabel.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 18),
            securityLabel.widthAnchor.constraint(equalToConstant: 144),
            securityLabel.heightAnchor.constraint(equalToConstant: 22),

            // Security Box
            securityPop.leadingAnchor.constraint(equalTo: securityLabel.trailingAnchor, constant: 6),
            securityPop.topAnchor.constraint(equalTo: securityLabel.topAnchor, constant: -4),
            securityPop.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            //Username label
            usernameLabel.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
            usernameLabel.widthAnchor.constraint(equalTo: securityLabel.widthAnchor),
            usernameLabel.heightAnchor.constraint(equalTo: usernameBox.heightAnchor),

            // Usernamw Box
            usernameBox.leadingAnchor.constraint(equalTo: usernameLabel.trailingAnchor, constant: 6),
            usernameBox.topAnchor.constraint(equalTo: usernameLabel.topAnchor, constant: -4),
            usernameBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            //Password label
            passwdLabel.leadingAnchor.constraint(equalTo: icon.leadingAnchor),
            passwdLabel.widthAnchor.constraint(equalTo: usernameLabel.widthAnchor),
            passwdLabel.heightAnchor.constraint(equalTo: passwdSecureBox.heightAnchor),

            // Password Secure Box
            passwdSecureBox.leadingAnchor.constraint(equalTo: passwdLabel.trailingAnchor, constant: 6),
            passwdSecureBox.topAnchor.constraint(equalTo: passwdLabel.topAnchor, constant: -4),
            passwdSecureBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Password Input Box
            passwdInputBox.leadingAnchor.constraint(equalTo: passwdSecureBox.leadingAnchor),
            passwdInputBox.topAnchor.constraint(equalTo: passwdSecureBox.topAnchor),
            passwdInputBox.trailingAnchor.constraint(equalTo: passwdSecureBox.trailingAnchor),
            passwdInputBox.heightAnchor.constraint(equalTo: passwdSecureBox.heightAnchor),

            // password toggle
            isShowPasswd.leadingAnchor.constraint(equalTo: passwdSecureBox.leadingAnchor),
            isShowPasswd.topAnchor.constraint(equalTo: passwdSecureBox.bottomAnchor, constant: 8),
            isShowPasswd.trailingAnchor.constraint(equalTo: passwdSecureBox.trailingAnchor),

            // Join button
            editButton.topAnchor.constraint(equalTo: isShowPasswd.bottomAnchor, constant: 20),
            editButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),
            editButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            editButton.widthAnchor.constraint(equalToConstant: 70),

            // Cancel Button
            cancelButton.topAnchor.constraint(equalTo: editButton.topAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: editButton.bottomAnchor),
            cancelButton.trailingAnchor.constraint(equalTo: editButton.leadingAnchor, constant: -12),
            cancelButton.widthAnchor.constraint(equalToConstant: 70)
        ]

        NSLayoutConstraint.activate(constraints)
        usernameHeightCon = usernameBox.heightAnchor.constraint(equalToConstant: 8)
        passwrdHeightCon = passwdSecureBox.heightAnchor.constraint(equalToConstant: 22)
        showPassToggleHeightCon = isShowPasswd.heightAnchor.constraint(equalToConstant: 14)

        hideMarginCon.append(usernameLabel.topAnchor.constraint(equalTo: securityLabel.bottomAnchor))
        hideMarginCon.append(passwdLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor))

        NSLayoutConstraint.activate(hideMarginCon)

        usernameHeightCon.isActive = true
        passwrdHeightCon.isActive = true
        showPassToggleHeightCon.isActive = true
    }

    @objc private func security(_ sender: Any?) {
        switch securityPop.title {
        case .none:
            self.usernameLabel.isHidden = true
            self.passwdLabel.isHidden = true
            self.usernameBox.isHidden = false
            self.passwdInputBox.isHidden = true
            self.passwdSecureBox.isHidden = true
            self.isShowPasswd.isHidden = true

            NSAnimationContext.runAnimationGroup({context in
                context.duration = 0.08
                context.allowsImplicitAnimation = true
                usernameHeightCon.animator().constant = 0
                passwrdHeightCon.animator().constant = 0
                showPassToggleHeightCon.animator().constant = 0
                hideMarginCon.forEach { const in
                    const.animator().constant = -4
                }
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: nil)

            controlJoinButton()
        case .wpa1_2_Personal,
             NSLocalizedString("WPA2/WPA3 Personal", comment: ""),
             .wpa2Personal,
             NSLocalizedString("WPA3 Personal", comment: ""):

            self.usernameLabel.isHidden = true
            self.usernameBox.isHidden = true
            self.passwdInputBox.isHidden = true

            NSAnimationContext.runAnimationGroup({context in
                context.duration = 0.08
                context.allowsImplicitAnimation = true
                usernameHeightCon.animator().constant = 0
                passwrdHeightCon.animator().constant = 22
                showPassToggleHeightCon.animator().constant = 14
                hideMarginCon[0].animator().constant = 0
                hideMarginCon[1].animator().constant = 8
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: {
                self.passwdSecureBox.isHidden = false
                self.isShowPasswd.isHidden = false
                self.passwdLabel.isHidden = false
            })

            controlJoinButton()

            passwdSecureBox.becomeFirstResponder()
        case .wpa1_2_Enterprise,
             NSLocalizedString("WPA2/WPA3 Enterprise", comment: ""),
             .wpa2Enterprise,
             NSLocalizedString("WPA3 Enterprise", comment: ""):

            self.passwdInputBox.isHidden = true

            NSAnimationContext.runAnimationGroup({context in
                context.duration = 0.08
                context.allowsImplicitAnimation = true
                usernameHeightCon.animator().constant = 22
                passwrdHeightCon.animator().constant = 22
                showPassToggleHeightCon.animator().constant = 14
                hideMarginCon.forEach { const in
                    const.animator().constant = 8
                }
                self.view.layoutSubtreeIfNeeded()
            }, completionHandler: {
                self.usernameBox.isHidden = false
                self.passwdSecureBox.isHidden = false
                self.isShowPasswd.isHidden = false
                self.usernameLabel.isHidden = false
                self.passwdLabel.isHidden = false
            })

            controlJoinButton()
            usernameBox.becomeFirstResponder()
        default:
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Encryption type unsupported", comment: "")
            alert.alertStyle = .critical
            alert.runModal()
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

    @objc private func editWiFi(_ sender: Any?) {
//        let networkInfo = NetworkInfo(ssid: ssidBox.stringValue)
//        networkInfo.auth.password = passwdInputBox.stringValue
//
//        switch securityPop.indexOfSelectedItem {
//        case 0:
//            networkInfo.auth.security = ITL80211_SECURITY_NONE
//
//        case 2:
//            networkInfo.auth.security = ITL80211_SECURITY_WPA_PERSONAL_MIXED
//        case 3:
//            networkInfo.auth.security = ITL80211_SECURITY_WPA2_PERSONAL
//
//        case 5:
//            networkInfo.auth.security = ITL80211_SECURITY_WPA_ENTERPRISE_MIXED
//        case 6:
//            networkInfo.auth.security = ITL80211_SECURITY_WPA2_ENTERPRISE
//
//        default:
//            networkInfo.auth.security = ITL80211_SECURITY_UNKNOWN
//        }
//
//        NetworkManager.connect(networkInfo: networkInfo, saveNetwork: isSave.state == .on)
//        close()
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
        // no password used, both password inputs are hidden
        if passwdInputBox.isHidden, passwdSecureBox.isHidden {
            editButton.isEnabled = true
            return
        }

        // password is too short, less than 8 characters
        guard (!passwdInputBox.isHidden || !passwdSecureBox.isHidden),
            passwdSecureBox.stringValue.count >= 8,
            passwdInputBox.stringValue.count >= 8  else {
            editButton.isEnabled = false
            return
        }

        // user name input shown but not filled in
        if !usernameBox.isHidden, usernameBox.stringValue.isEmpty {
            editButton.isEnabled = false
            return
        }

        // everything is OK
        editButton.isEnabled = true
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

// MARK: Localization strings

private extension String {
    static let title = NSLocalizedString("%@'s Credentials")
    static let subTitle = NSLocalizedString("View saved credentials from keychain for the selected network.")
    static let security = NSLocalizedString("Security:")
    static let none = NSLocalizedString(ITL80211_SECURITY_NONE.description)
    static let wpa1_2_Personal = NSLocalizedString(ITL80211_SECURITY_WPA_PERSONAL_MIXED.description)
    static let wpa2Personal = NSLocalizedString(ITL80211_SECURITY_WPA2_PERSONAL.description)
    static let wpa1_2_Enterprise = NSLocalizedString(ITL80211_SECURITY_WPA_ENTERPRISE_MIXED.description)
    static let wpa2Enterprise = NSLocalizedString(ITL80211_SECURITY_WPA2_ENTERPRISE.description)
    static let username = NSLocalizedString("Username:")
    static let password = NSLocalizedString("Password:")
    static let edit = NSLocalizedString("Edit")
    static let exit = NSLocalizedString("Cancel")
    static let showPassword = NSLocalizedString("Show password")
}
