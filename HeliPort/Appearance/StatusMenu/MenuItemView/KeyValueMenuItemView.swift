//
//  KeyValueMenuItemView.swift
//  HeliPort
//
//  Created by Bat.bat on 24/6/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class KeyValueMenuItemView: HidableMenuItemView {

    enum Inset: CGFloat {
        case standard = 14
        case staInfo = 34
    }

    private let keyLabel: NSTextField
    private let valueLabel: NSTextField

    init(key: String, value: String? = nil, inset: Inset) {
        keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        keyLabel.textColor = .secondaryLabelColor

        valueLabel = NSTextField(labelWithString: value ?? "(null)")
        valueLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor

        let height = {
            if #available(macOS 11, *) {
                return NSMenuItem.ItemHeight.textModern
            }
            return NSMenuItem.ItemHeight.textLegacy
        }()

        super.init(height: height)
        addSubview(keyLabel)
        addSubview(valueLabel)

        translatesAutoresizingMaskIntoConstraints = false
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        valueLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        NSLayoutConstraint.activate([
            keyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            keyLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset.rawValue),
            valueLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var value: String? {
        didSet {
            if value != oldValue {
                valueLabel.stringValue = value ?? "(null)"
            }
        }
    }
}
