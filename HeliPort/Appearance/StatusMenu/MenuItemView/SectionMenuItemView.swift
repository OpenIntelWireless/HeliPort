//
//  SectionMenuItemView.swift
//  HeliPort
//
//  Created by Bat.bat on 27/6/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Foundation
import Cocoa

@available(macOS 11, *)
class SectionMenuItemView: SelectableMenuItemView {

    // MARK: Initializers

    private let label: NSTextField = {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .secondaryLabelColor
        return label
    }()

    private static let chevronDown = NSImage(systemSymbolName: "chevron.down")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
    private static let chevronRight = NSImage(systemSymbolName: "chevron.right")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))

    private let chevronImage: NSImageView = {
        let imageView = NSImageView()
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.image = chevronRight
        imageView.wantsLayer = true
        imageView.image?.isTemplate = true
        imageView.alphaValue = 0.9
        return imageView
    }()

    let expandAction: ((Bool) -> Void)?

    var title: String {
        willSet {
            label.stringValue = newValue
        }
    }

    var isExpanded: Bool = false {
        willSet {
            guard newValue != isExpanded else { return }
            self.expandAction?(newValue)
            animateImageTransition(imageView: chevronImage,
                                   toImage: newValue ? SectionMenuItemView.chevronDown
                                                     : SectionMenuItemView.chevronRight,
                                   onComplete: nil)
        }
    }

    init(title: String, expandAction: ((Bool) -> Void)? = nil) {
        self.title = title
        self.expandAction = expandAction
        super.init(height: .textModern, hoverStyle: expandAction == nil ? .none : .greytint)

        chevronImage.isHidden = expandAction == nil
        label.stringValue = title

        addSubview(label)
        addSubview(chevronImage)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Private

    private func animateImageTransition(imageView: NSImageView, toImage: NSImage?, onComplete: (() -> Void)? = nil) {
        // Fade out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            imageView.animator().alphaValue = 0.0
        }, completionHandler: {
            imageView.image = toImage

            // Fade in
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                imageView.animator().alphaValue = 0.9
            }, completionHandler: onComplete)
        })
    }

    // MARK: Overrides

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        isExpanded = !isExpanded
    }

    internal override func setupLayout() {
        super.setupLayout()
        translatesAutoresizingMaskIntoConstraints = false
        self.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            chevronImage.firstBaselineAnchor.constraint(equalTo: label.firstBaselineAnchor),
            chevronImage.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -13)
        ])
    }
}
