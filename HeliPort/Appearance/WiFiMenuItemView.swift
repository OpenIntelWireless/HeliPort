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
    let menuItemView: NSVisualEffectView = {
        let menuItemView = NSVisualEffectView()
        menuItemView.state = .active
        menuItemView.material = .popover
        menuItemView.isEmphasized = false
        menuItemView.blendingMode = .behindWindow
        menuItemView.translatesAutoresizingMaskIntoConstraints = false
        return menuItemView
    }()

    let statusImage: NSImageView = {
        let statusImage = NSImageView()
        statusImage.image = NSImage.init(named: "NSMenuOnStateTemplate")
        statusImage.image?.isTemplate = true
        statusImage.translatesAutoresizingMaskIntoConstraints = false
        return statusImage
    }()

    let ssidLabel: NSTextView = {
        let ssidLabel = NSTextView()
        ssidLabel.drawsBackground = false
        ssidLabel.isEditable = false
        ssidLabel.isSelectable = false
        ssidLabel.font = NSFont.systemFont(ofSize: 14)
        ssidLabel.translatesAutoresizingMaskIntoConstraints = false
        return ssidLabel
    }()

    let lockImage: NSImageView = {
        let lockImage = NSImageView()
        lockImage.image = NSImage.init(named: "NSLockLockedTemplate")
        lockImage.translatesAutoresizingMaskIntoConstraints = false
        return lockImage
    }()

    let signalImage: NSImageView = {
        let signalImage = NSImageView()
        signalImage.translatesAutoresizingMaskIntoConstraints = false
        return signalImage
    }()

    var highlightColor: NSColor = NSColor.white
    var normalColor: NSColor = NSColor.white
    var isMouseOver: Bool = false {
        willSet(hover) {
            menuItemView.material = hover ? .selection : .popover
            menuItemView.isEmphasized = hover
            ssidLabel.textColor = hover ? highlightColor : normalColor
            if #available(OSX 10.14, *) {
                statusImage.contentTintColor = hover ? highlightColor : normalColor
                lockImage.contentTintColor = hover ? highlightColor : normalColor
                signalImage.contentTintColor = hover ? highlightColor : normalColor
            }
        }
    }

    var darkModeEnabled: Bool = false {
        willSet(enabled) {
            highlightColor = NSColor.white
            normalColor = enabled ? NSColor.white : NSColor.black
        }
    }

    var visible: Bool = true {
        willSet(visible) {
            setFrameSize(NSSize(
                width: self.frame.width,
                height: visible ? 18 : 0
            ))
        }
    }

    var currentWindow: NSWindow?

    var networkInfo: NetworkInfo {
        willSet(networkInfo) {
            statusImage.isHidden = !networkInfo.isConnected
            ssidLabel.string = networkInfo.ssid
            lockImage.isHidden = networkInfo.auth.security == NetworkInfo.AuthSecurity.NONE.rawValue
            signalImage.image = getRssiImage(networkInfo.rssi)
        }
    }

    func setupLayout() {
        menuItemView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
        menuItemView.heightAnchor.constraint(equalTo: heightAnchor).isActive = true

        statusImage.centerYAnchor.constraint(equalTo: menuItemView.centerYAnchor).isActive = true
        statusImage.leftAnchor.constraint(equalTo: menuItemView.leftAnchor, constant: 5).isActive = true

        signalImage.centerYAnchor.constraint(equalTo: menuItemView.centerYAnchor).isActive = true
        signalImage.heightAnchor.constraint(equalToConstant: 14).isActive = true
        signalImage.rightAnchor.constraint(equalTo: menuItemView.rightAnchor, constant: -10).isActive = true

        lockImage.centerYAnchor.constraint(equalTo: menuItemView.centerYAnchor).isActive = true
        lockImage.rightAnchor.constraint(equalTo: signalImage.leftAnchor, constant: -10).isActive = true

        ssidLabel.centerYAnchor.constraint(equalTo: menuItemView.centerYAnchor).isActive = true
        ssidLabel.heightAnchor.constraint(equalTo: menuItemView.heightAnchor).isActive = true
        ssidLabel.leftAnchor.constraint(equalTo: statusImage.rightAnchor, constant: -2).isActive = true
        ssidLabel.rightAnchor.constraint(equalTo: lockImage.leftAnchor, constant: -10).isActive = true
    }

    init(networkInfo: NetworkInfo) {
        self.networkInfo = networkInfo
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: 0,
            height: 18
        ))

        darkModeEnabled = isDarkMode()

        menuItemView.addSubview(statusImage)
        menuItemView.addSubview(ssidLabel)
        menuItemView.addSubview(lockImage)
        menuItemView.addSubview(signalImage)

        addSubview(menuItemView)
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
        NetworkManager.connect(networkInfo: networkInfo)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        //Fix mouseUp event after losing focus
        //https://stackoverflow.com/questions/15075033/weird-issue-with-nsmenuitem-custom-view-and-mouseup
        super.viewWillMove(toWindow: newWindow)
        newWindow?.becomeKey()
        currentWindow = newWindow
    }

    override func draw(_ rect: NSRect) {
        darkModeEnabled = isDarkMode()
        checkHighlight()
    }

    func isDarkMode() -> Bool {
        if #available(OSX 10.14, *) {
            return self.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        return false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func getRssiImage(_ RSSI: Int) -> NSImage? {
        var signalImageName: String
        switch RSSI {
        case ..<(0):
            signalImageName = "WiFiSignalStrengthPoor"
        case ..<(20):
            signalImageName = "WiFiSignalStrengthFair"
        case ..<(40):
            signalImageName = "WiFiSignalStrengthGood"
        default:
            signalImageName = "WiFiSignalStrengthExcellent"
        }
        return NSImage.init(named: signalImageName)
    }
}
