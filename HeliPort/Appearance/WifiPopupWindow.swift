//
//  WifiPopupWindow.swift
//  HeliPort
//
//  Created by Igor Kulman on 22/06/2020.
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
