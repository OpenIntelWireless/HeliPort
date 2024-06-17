//
//  WiFiMenuItemView.swift
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

import Foundation
import Cocoa

class WifiMenuItemView: NSView {

    // MARK: Initializers

    private var currentWindow: NSWindow?
    private var heightConstraint: NSLayoutConstraint!

    private let menuBarHeight: CGFloat = {
        if #available(macOS 11, *) {
            return 22
        } else {
            return 19
        }
    }()

    private let effectView: NSVisualEffectView = {
        let effectView = NSVisualEffectView()
        effectView.material = .popover
        effectView.state = .active
        effectView.isEmphasized = true
        effectView.blendingMode = .behindWindow
        return effectView
    }()

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

    public init(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        self.addSubview(effectView)
        effectView.addSubview(statusImage)
        effectView.addSubview(ssidLabel)
        effectView.addSubview(lockImage)
        effectView.addSubview(signalImage)

        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    public var networkInfo: NetworkInfo {
        willSet(networkInfo) {
            ssidLabel.stringValue = networkInfo.ssid
            lockImage.isHidden = networkInfo.auth.security == ITL80211_SECURITY_NONE
            signalImage.image = StatusBarIcon.getRssiImage(Int16(networkInfo.rssi))
            layoutSubtreeIfNeeded()
        }
    }

    public var visible: Bool = true {
        willSet(visible) {
            isHidden = !visible
            heightConstraint.constant = visible ? menuBarHeight : 0
            layoutSubtreeIfNeeded()
        }
    }

    public var connected: Bool = false {
        willSet(connected) {
            statusImage.isHidden = !connected
        }
    }

    public func checkHighlight() {
        if visible, let position = currentWindow?.mouseLocationOutsideOfEventStream {
            isMouseOver = bounds.contains(convert(position, from: nil))
        }
    }

    // MARK: Private

    private var isMouseOver: Bool = false {
        willSet(hover) {
            effectView.material = hover ? .selection : .popover
            effectView.isEmphasized = hover

            ssidLabel.textColor = hover ? .selectedMenuItemTextColor : .controlTextColor

            statusImage.cell?.backgroundStyle = hover ? .emphasized : .normal
            lockImage.cell?.backgroundStyle = hover ? .emphasized : .normal
            signalImage.cell?.backgroundStyle = hover ? .emphasized : .normal
        }
    }

    private func setupLayout() {

        let effectPadding: CGFloat
        let statusPadding: CGFloat
        let statusWidth: CGFloat
        let lockWidth: CGFloat
        if #available(macOS 11, *) {
            effectView.wantsLayer = true
            effectView.layer?.cornerRadius = 4
            effectView.layer?.masksToBounds = true
            effectPadding = 5
            statusPadding = 10
            statusWidth = 15
            lockWidth = 16
        } else {
            effectPadding = 0
            statusPadding = 6
            statusWidth = 12
            lockWidth = 10
        }

        heightConstraint = heightAnchor.constraint(equalToConstant: menuBarHeight)
        heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 1000)
        heightConstraint.isActive = true

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

        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        effectView.leftAnchor.constraint(equalTo: self.leftAnchor, constant: effectPadding).isActive = true
        effectView.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -effectPadding).isActive = true
        effectView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        effectView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    // MARK: Overrides

    override func mouseUp(with event: NSEvent) {
        isMouseOver = false // NSWindow pop up could escape mouseExit
        enclosingMenuItem?.menu?.cancelTracking()
        if !connected {
            NetworkManager.connect(networkInfo: networkInfo, saveNetwork: true)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        // Fix mouseUp event after losing focus
        // https://stackoverflow.com/questions/15075033/weird-issue-with-nsmenuitem-custom-view-and-mouseup
        super.viewWillMove(toWindow: newWindow)
        newWindow?.becomeKey()
        currentWindow = newWindow
    }

    override func draw(_ rect: NSRect) {
        checkHighlight()
    }

    override func layout() {
        super.layout()
        if #available(macOS 11, *) {
            effectView.frame = CGRect(x: 5,                     // effectPadding
                                      y: 0,
                                      width: bounds.width - 10, // effectPadding * 2
                                      height: bounds.height)
        } else {
            effectView.frame = bounds
        }
    }
}
