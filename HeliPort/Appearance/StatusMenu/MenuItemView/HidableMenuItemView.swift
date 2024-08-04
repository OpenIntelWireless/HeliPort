//
//  HidableMenuItemView.swift
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

class HidableMenuItemView: NSView {
    private let height: CGFloat
    private var heightConstraint: NSLayoutConstraint!

    var visible: Bool = true {
        willSet(visible) {
            // Manually adjust visibility for item views prior to macOS 14
            if #unavailable(macOS 14) {
                isHidden = !visible
                heightConstraint.constant = visible ? height : 0
                layoutSubtreeIfNeeded()
            }
        }
    }

    init(height: NSMenuItem.ItemHeight) {
        self.height = height.rawValue
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        heightConstraint = heightAnchor.constraint(equalToConstant: height.rawValue)
        heightConstraint.priority = NSLayoutConstraint.Priority(rawValue: 1000)
        heightConstraint.isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
