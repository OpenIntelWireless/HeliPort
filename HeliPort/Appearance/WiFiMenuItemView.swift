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

    let statusImage: NSImageView = {
        let statusImage = NSImageView()
        statusImage.image = NSImage(named: NSImage.menuOnStateTemplateName)
        statusImage.image?.isTemplate = true
        statusImage.translatesAutoresizingMaskIntoConstraints = false
        statusImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        statusImage.isHidden = true
        return statusImage
    }()

    let ssidLabel: NSTextField = {
        let ssidLabel = NSTextField()
        ssidLabel.isBordered = false
        ssidLabel.usesSingleLineMode = true
        ssidLabel.maximumNumberOfLines = 1
        ssidLabel.drawsBackground = false
        ssidLabel.isEditable = false
        ssidLabel.isSelectable = false
        ssidLabel.font = NSFont.systemFont(ofSize: 14)
        ssidLabel.translatesAutoresizingMaskIntoConstraints = false
        return ssidLabel
    }()

    let lockImage: NSImageView = {
        let lockImage = NSImageView()
        lockImage.image = NSImage.init(named: NSImage.lockLockedTemplateName)
        lockImage.image?.isTemplate = true
        lockImage.translatesAutoresizingMaskIntoConstraints = false
        lockImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return lockImage
    }()

    let signalImage: NSImageView = {
        let signalImage = NSImageView()
        signalImage.image?.isTemplate = true
        signalImage.translatesAutoresizingMaskIntoConstraints = false
        signalImage.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        return signalImage
    }()

    var isMouseOver: Bool = false {
        willSet(hover) {
            (superview as? NSVisualEffectView)?.material = hover ? .selection : .popover
            (superview as? NSVisualEffectView)?.isEmphasized = hover
            ssidLabel.textColor = hover ? .white : .textColor
            if #available(OSX 10.14, *) {
                statusImage.contentTintColor = hover ? .white : .textColor
                lockImage.contentTintColor = hover ? .white : .textColor
                signalImage.contentTintColor = hover ? .white : .textColor
            }
        }
    }

    var visible: Bool = true {
        willSet(visible) {
            heightConstraint.constant = visible ? 19 : 0
            layoutSubtreeIfNeeded()
        }
    }

    var connected: Bool = false {
        willSet(connected) {
            statusImage.isHidden = !connected
        }
    }

    var currentWindow: NSWindow?

    var networkInfo: NetworkInfo {
        willSet(networkInfo) {
            ssidLabel.stringValue = networkInfo.ssid
            lockImage.isHidden = networkInfo.auth.security == ITL80211_SECURITY_NONE
            signalImage.image = WifiMenuItemView.getRssiImage(networkInfo.rssi)
            layoutSubtreeIfNeeded()
        }
    }

    var heightConstraint: NSLayoutConstraint!

    func setupLayout() {
        heightConstraint = heightAnchor.constraint(equalToConstant: 19)
        heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 1000)
        heightConstraint.isActive = true

        statusImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        statusImage.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 6).isActive = true
        statusImage.widthAnchor.constraint(equalToConstant: 12).isActive = true

        ssidLabel.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        ssidLabel.leadingAnchor.constraint(equalTo: statusImage.trailingAnchor, constant: 3).isActive = true
        ssidLabel.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        ssidLabel.bottomAnchor.constraint(equalTo: self.bottomAnchor).isActive = true

        lockImage.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        lockImage.leadingAnchor.constraint(equalTo: ssidLabel.trailingAnchor, constant: 10).isActive = true
        lockImage.widthAnchor.constraint(equalToConstant: 10).isActive = true

        signalImage.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 1).isActive = true
        signalImage.leadingAnchor.constraint(equalTo: lockImage.trailingAnchor, constant: 12).isActive = true
        signalImage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -12).isActive = true
        signalImage.widthAnchor.constraint(equalToConstant: 18).isActive = true
    }

    init(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        super.init(frame: NSRect.zero)

        self.addSubview(statusImage)
        self.addSubview(ssidLabel)
        self.addSubview(lockImage)
        self.addSubview(signalImage)

        setupLayout()
    }

    func checkHighlight() {
        if visible, let position = currentWindow?.mouseLocationOutsideOfEventStream {
            isMouseOver = bounds.contains(convert(position, from: nil))
        }
    }

    override func mouseUp(with event: NSEvent) {
        isMouseOver = false // NSWindow pop up could escape mouseExit
        enclosingMenuItem?.menu?.cancelTracking()
        if !connected {
            NetworkManager.connect(networkInfo: networkInfo)
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        //Fix mouseUp event after losing focus
        //https://stackoverflow.com/questions/15075033/weird-issue-with-nsmenuitem-custom-view-and-mouseup
        super.viewWillMove(toWindow: newWindow)
        newWindow?.becomeKey()
        currentWindow = newWindow
    }

    override func draw(_ rect: NSRect) {
        checkHighlight()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func getRssiImage(_ RSSI: Int) -> NSImage? {
        var signalImageName: NSImage
        switch RSSI {
        case ..<(-100):
            signalImageName = #imageLiteral(resourceName: "WiFiStateScanning1")
        case ..<(-80):
            signalImageName = #imageLiteral(resourceName: "WiFiSignalStrengthFair")
        case ..<(-60):
            signalImageName = #imageLiteral(resourceName: "WiFiSignalStrengthGood")
        default:
            signalImageName = #imageLiteral(resourceName: "WiFiStateOn")
        }
        return signalImageName
    }
}
