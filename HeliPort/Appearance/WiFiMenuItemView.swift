//
//  WiFiMenuItemView.swift
//  HeliPort
//
//  Created by 梁怀宇 on 2020/4/3.
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

class WifiMenuItemView: NSView {
    var menuItemView: NSVisualEffectView
    var statusImage: NSImageView
    var ssidLabel: NSTextView
    var lockImage: NSImageView
    var signalImage: NSImageView
    var highlightColor: NSColor
    var normalColor: NSColor
    var isMouseOver: Bool = false

    var networkInfo: NetworkInfo

    init(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        menuItemView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 285, height: 20))
        statusImage = NSImageView(frame: NSRect(x: 3, y: 0, width: 18, height: 18))
        ssidLabel = NSTextView(frame: NSRect(x: 18, y: 0, width: 206, height: 18))
        lockImage = NSImageView(frame: NSRect(x: 231, y: 0, width: 18, height: 18))
        signalImage = NSImageView(frame: NSRect(x: 257, y: 0, width: 18, height: 18))
        isMouseOver = false

        highlightColor = NSColor.white
        normalColor = NSColor.black

        super.init(frame: NSRect(x: 0, y: 0, width: 285, height: 20))

        if isDarkMode(view: menuItemView) {
            highlightColor = NSColor.white
            normalColor = NSColor.white
        }

        menuItemView.addTrackingRect(menuItemView.bounds, owner: menuItemView, userData: nil, assumeInside: false)
        menuItemView.state = .active
        menuItemView.material = .popover
        menuItemView.isEmphasized = false
        menuItemView.blendingMode = .behindWindow

        statusImage.image = NSImage.init(named: "NSMenuOnStateTemplate")
        statusImage.image?.isTemplate = true
        statusImage.isHidden = !networkInfo.isConnected
        menuItemView.addSubview(statusImage)

        ssidLabel.drawsBackground = false
        ssidLabel.isEditable = false
        ssidLabel.isSelectable = false
        ssidLabel.font = NSFont.systemFont(ofSize: 14)
        ssidLabel.string = networkInfo.ssid
        menuItemView.addSubview(ssidLabel)

        lockImage.image = NSImage.init(named: "NSLockLockedTemplate")
        lockImage.isHidden = networkInfo.auth.security == NetworkInfo.AuthSecurity.NONE.rawValue
        menuItemView.addSubview(lockImage)

        signalImage.image = NSImage.init(named: "WiFiSignalStrengthExcellent")
        //signalImage?.contentTintColor =
        menuItemView.addSubview(signalImage)

        addSubview(menuItemView)

        autoresizesSubviews = true
        autoresizingMask = [.width, .height]
        menuItemView.autoresizingMask = [.width, .height]
    }

    func updateNetworkInfo(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        statusImage.isHidden = !networkInfo.isConnected
        ssidLabel.string = networkInfo.ssid
        lockImage.isHidden = networkInfo.auth.security == NetworkInfo.AuthSecurity.NONE.rawValue
    }

    func show() {
        setFrameSize(NSSize(width: 285, height: 20))
    }

    func hide() {
        setFrameSize(NSSize(width: 285, height: 0))
    }

    override func mouseEntered(with event: NSEvent) {
        menuItemView.material = .selection
        menuItemView.isEmphasized = true
        ssidLabel.textColor = highlightColor
        if #available(OSX 10.14, *) {
            statusImage.contentTintColor = highlightColor
            lockImage.contentTintColor = highlightColor
            signalImage.contentTintColor = highlightColor
        }
        isMouseOver = true
    }

    override func mouseExited(with event: NSEvent) {
        menuItemView.material = .popover
        menuItemView.isEmphasized = false
        ssidLabel.textColor = normalColor
        if #available(OSX 10.14, *) {
            statusImage.contentTintColor = normalColor
            lockImage.contentTintColor = normalColor
            signalImage.contentTintColor = normalColor
        }
        isMouseOver = false
    }

    override func mouseUp(with event: NSEvent) {
        menuItemView.material = .popover
        menuItemView.isEmphasized = false
        isMouseOver = false // NSWindow pop up could escape mouseExit
        ssidLabel.textColor = normalColor
        if #available(OSX 10.14, *) {
            statusImage.contentTintColor = normalColor
            lockImage.contentTintColor = normalColor
            signalImage.contentTintColor = normalColor
        }
        statusBar.menu?.cancelTracking()
        NetworkManager.connect(networkInfo: networkInfo)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        //Fix mouseUp event after losing focus
        //https://stackoverflow.com/questions/15075033/weird-issue-with-nsmenuitem-custom-view-and-mouseup
        super.viewWillMove(toWindow: newWindow)
        newWindow?.becomeKey()
        updateTrackingAreas()
    }

    override func draw(_ rect: NSRect) {
        if isDarkMode(view: menuItemView) {
            highlightColor = NSColor.white
            normalColor = NSColor.white
        } else {
            highlightColor = NSColor.white
            normalColor = NSColor.black
        }
        if !isMouseOver {
            ssidLabel.textColor = normalColor
            if #available(OSX 10.14, *) {
                statusImage.contentTintColor = normalColor
                lockImage.contentTintColor = normalColor
                signalImage.contentTintColor = normalColor
            }
        }
        //menuItemView?.isHidden = !(enclosingMenuItem?.isHighlighted ?? false)
    }

    func isDarkMode(view: NSView) -> Bool {
        if #available(OSX 10.14, *) {
            return view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
