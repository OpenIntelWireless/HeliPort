//
//  WiFiMenuItemViewLegacy.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/3.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class WifiMenuItemViewLegacy: SelectableMenuItemView, WifiMenuItemView {

    // MARK: Initializers

    private let statusImage: NSImageView = {
        let statusImage = NSImageView()
        statusImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        statusImage.isHidden = true

        if #available(OSX 11.0, *) {
            statusImage.image = NSImage(named: NSImage.menuOnStateTemplateName)?
                                .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13,
                                                                                     weight: .bold,
                                                                                     scale: .small))
        } else {
            statusImage.image = NSImage(named: NSImage.menuOnStateTemplateName)
        }

        return statusImage
    }()

    private let lockImage: NSImageView = {
        let lockImage = NSImageView()
        lockImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        if #available(OSX 11.0, *) {
            lockImage.image = NSImage(named: NSImage.lockLockedTemplateName)?
                              .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14,
                                                                                   weight: .semibold,
                                                                                   scale: .medium))
        } else {
            lockImage.image = NSImage(named: NSImage.lockLockedTemplateName)
        }

        return lockImage
    }()

    private let signalImage: NSImageView = {
        let signalImage = NSImageView()
        signalImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return signalImage
    }()

    private let ssidLabel: NSTextField = {
        let ssidLabel = NSTextField(labelWithString: "")

        if #available(macOS 11, *) {
            ssidLabel.font = NSFont.menuFont(ofSize: 0)
        } else {
            ssidLabel.font = NSFont.systemFont(ofSize: 14)
        }

        return ssidLabel
    }()

    init(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        let height: NSMenuItem.ItemHeight = {
            if #available(macOS 11, *) {
                return .textModern
            }
            return .textLegacy
        }()
        super.init(height: height, hoverStyle: .selection)

        addSubview(statusImage)
        addSubview(ssidLabel)
        addSubview(lockImage)
        addSubview(signalImage)

        setupLayout()

        // willSet/didSet will not be called during initialization
        defer {
            self.networkInfo = networkInfo
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    public var networkInfo: NetworkInfo {
        willSet(networkInfo) {
            ssidLabel.stringValue = networkInfo.ssid
            layoutSubtreeIfNeeded()
        }
        didSet {
            updateImages()
        }
    }

    public var connected: Bool = false {
        willSet(connected) {
            statusImage.isHidden = !connected
        }
    }

    public func updateImages() {
        signalImage.image = StatusBarIcon.shared().getRssiImage(rssi: Int16(networkInfo.rssi))
        lockImage.isHidden = networkInfo.auth.security == ITL80211_SECURITY_NONE
    }

    // MARK: Overrides

    override var isMouseOver: Bool {
        willSet(hover) {
            super.isMouseOver = hover

            ssidLabel.textColor = hover ? .selectedMenuItemTextColor : .controlTextColor

            statusImage.cell?.backgroundStyle = hover ? .emphasized : .normal
            lockImage.cell?.backgroundStyle = hover ? .emphasized : .normal
            signalImage.cell?.backgroundStyle = hover ? .emphasized : .normal
        }
    }

    override func setupLayout() {
        super.setupLayout()

        let (statusPadding, statusWidth, lockWidth): (CGFloat, CGFloat, CGFloat) = {
            if #available(macOS 11, *) {
                return (10, 15, 16)
            } else {
                return (6, 12, 10)
            }
        }()

        statusImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        statusImage.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: statusPadding).isActive = true
        statusImage.widthAnchor.constraint(equalToConstant: statusWidth).isActive = true

        ssidLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        ssidLabel.leadingAnchor.constraint(equalTo: statusImage.trailingAnchor, constant: 3).isActive = true

        lockImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        lockImage.leadingAnchor.constraint(equalTo: ssidLabel.trailingAnchor, constant: 10).isActive = true
        lockImage.widthAnchor.constraint(equalToConstant: lockWidth).isActive = true

        signalImage.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 1).isActive = true
        signalImage.leadingAnchor.constraint(equalTo: lockImage.trailingAnchor, constant: 12).isActive = true
        signalImage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12).isActive = true
        signalImage.widthAnchor.constraint(equalToConstant: 18).isActive = true
    }

    override func performMenuItemAction() {
        if !connected {
            NetworkManager.connect(networkInfo: networkInfo, saveNetwork: true)
        }

        isMouseOver = false // NSWindow pop up could escape mouseExit

        guard let menuItem = enclosingMenuItem, let menu = menuItem.menu else { return }
        menu.cancelTracking()
        menu.performActionForItem(at: menu.index(of: menuItem))
    }
}
