//
//  HPMenuItem.swift
//  HeliPort
//
//  Created by Bat.bat on 5/8/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

/// Use this class instead of `NSMenuItem` when applying a custom view
class HPMenuItem: NSMenuItem {

    var highlightable: Bool = false

    convenience init(highlightable: Bool = false) {
        self.init()
        self.highlightable = highlightable
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
        super.init(title: string, action: selector, keyEquivalent: charCode)
    }

    override var isHidden: Bool {
        willSet {
            (self.view as? HidableMenuItemView)?.visible = !newValue
        }
    }

    override func _canBeHighlighted() -> Bool {
        return highlightable || super._canBeHighlighted()
    }
}
