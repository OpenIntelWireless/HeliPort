//
//  SelectableMenuItemView.swift
//  HeliPort
//
//  Created by Bat.bat on 20/6/2024.
//  Copyright © 2024 OpenIntelWireless. All rights reserved.
//

/*
 * This program and the accompanying materials are licensed and made available
 * under the terms and conditions of the The 3-Clause BSD License
 * which accompanies this distribution. The full text of the license may be found at
 * https://opensource.org/licenses/BSD-3-Clause
 */

import Cocoa

class SelectableMenuItemView: HidableMenuItemView {

    private class HoverView: NSView {
        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            NSColor(named: "HoverColor")?.setFill()
            dirtyRect.fill()
        }
    }

    // MARK: Initializers

    private var currentWindow: NSWindow?
    private let effectView: NSView?

    private let effectPadding: CGFloat = {
        if #available(macOS 11, *) {
            return 5
        }
        return 0
    }()

    init(height: NSMenuItem.ItemHeight, hoverStyle: HoverStyle) {
        switch hoverStyle {
        case .none:
            effectView = nil
        case .greytint:
            effectView = HoverView()
            effectView?.isHidden = true
        case .selection:
            let view = NSVisualEffectView()
            view.material = .popover
            view.state = .active
            view.isEmphasized = true
            view.blendingMode = .behindWindow
            effectView = view
        }

        super.init(height: height)
        if let view = effectView { self.addSubview(view) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Public

    enum HoverStyle {
        case none
        case selection
        case greytint
    }

    func checkHighlight() {
        if effectView != nil, let position = currentWindow?.mouseLocationOutsideOfEventStream {
            isMouseOver = bounds.contains(convert(position, from: nil))
        }
    }

    var isMouseOver: Bool = false {
        willSet(hover) {
            if let view = effectView as? NSVisualEffectView {
                view.material = hover ? .selection : .popover
            } else {
                effectView?.isHidden = !hover
            }
        }
    }

    func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        if #available(macOS 11, *) {
            effectView?.wantsLayer = true
            effectView?.layer?.cornerRadius = 4
            effectView?.layer?.masksToBounds = true
        }

        effectView?.translatesAutoresizingMaskIntoConstraints = false
        effectView?.subviews.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        effectView?.leftAnchor.constraint(equalTo: self.leftAnchor, constant: effectPadding).isActive = true
        effectView?.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -effectPadding).isActive = true
        effectView?.topAnchor.constraint(equalTo: topAnchor).isActive = true
        effectView?.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
    }

    func performMenuItemAction() {
        guard let menuItem = enclosingMenuItem, let menu = menuItem.menu,
              menuItem.isEnabled else {
            return
        }

        isMouseOver = false // NSWindow pop up could escape mouseExit
        menu.cancelTracking()
        menu.performActionForItem(at: menu.index(of: menuItem))
    }

    // MARK: Overrides

    override func mouseUp(with event: NSEvent) {
        guard let view = effectView else {
            performMenuItemAction()
            return
        }

        // Simulate original click flash animtion
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.06
            view.animator().alphaValue = 0
        }, completionHandler: {
            self.checkHighlight()
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.06
                view.animator().alphaValue = 1
            }, completionHandler: {
                self.performMenuItemAction()
            })
        })
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        // Fix mouseUp event after losing focus
        // https://stackoverflow.com/questions/15075033/weird-issue-with-nsmenuitem-custom-view-and-mouseup
        super.viewWillMove(toWindow: newWindow)
        newWindow?.becomeKey()
        currentWindow = newWindow
    }

    override func layout() {
        super.layout()
        if #available(macOS 11, *) {
            effectView?.frame = CGRect(x: effectPadding, y: 0,
                                      width: bounds.width - effectPadding * 2,
                                      height: bounds.height)
        } else {
            effectView?.frame = bounds
        }
    }
}
