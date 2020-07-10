//
//  WifiPopupWindow.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation
import Cocoa

final class WifiPopupWindow: NSWindow {
    init(networkInfo: NetworkInfo, getAuthInfoCallback: @escaping (_ auth: NetworkAuth, _ savePassword: Bool) -> Void) {
        super.init(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: 450,
                height: 247
            ),
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )

        let wifiPopView: WiFiPopoverSubview = WiFiPopoverSubview(
            popWindow: self,
            networkInfo: networkInfo,
            getAuthInfoCallback: getAuthInfoCallback
        )
        contentView = wifiPopView
        isReleasedWhenClosed = false
        level = .floating
    }

    func show() {
        makeKeyAndOrderFront(self)
        center()
    }
}
