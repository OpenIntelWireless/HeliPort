//
//  NSMenuItem+Extensions.swift
//  HeliPort
//
//  Created by Igor Kulman on 29/06/2020.
//  Copyright © 2020 OpenIntelWireless. All rights reserved.
//

import Foundation
import Cocoa

extension NSMenuItem {
    convenience init(title: String) {
        self.init(title: title, action: nil, keyEquivalent: "")
    }
}
